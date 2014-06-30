local require = require

local OB = require('estrela.io.ob')
local OB_finish = OB.finish
local OB_flush = OB.flush
local OB_levels = OB.levels
local OB_print = OB.print
local OB_start = OB.start

local assert = assert
local debug = require('debug')
local debug_traceback = debug.traceback
local error = error
local io_open = io.open
local ipairs = ipairs
local loadstring = loadstring
local next = next
local pairs = pairs
local setmetatable = setmetatable
local table_concat = table.concat
local table_insert = table.insert
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack
local xpcall = xpcall

local ngx_gsub = ngx.re.gsub
local ngx_match = ngx.re.match

local Router = require('estrela.ngx.router')
local Request = require('estrela.ngx.request')
local Response = require('estrela.ngx.response')

local env_get_root = require('estrela.util.env').get_root
local path_join = require('estrela.util.path').join

local S = require('estrela.util.string')
local S_split = S.split
local S_starts = S.starts
local S_trim = S.trim
local S_htmlencode = S.htmlencode

local _config_private = {}

function _config_private:get(path, default)
    local r = self
    local p, l = 1, #path

    while p <= l do
        local c = string.find(path, '.', p, true) or (l + 1)
        local key = string.sub(path, p, c - 1)
        if r[key] == nil then
            return default
        end
        p = c + 1
        r = r[key]
    end

    return r
end

local _error = {}

function _error:clean()
    self.code  = 0
    self.msg   = nil
    self.file  = nil
    self.line  = nil
    self.stack = nil
    self.aborted_code = nil -- используется для передачи кода ошибки из app:abort() в обработчик xpcall
    self.redirect = nil -- используется для передачи url и статуса редиректа из app:redirect()
end

function _error:init(code, msg)
    local info = msg and self:_splitErrorLineByWhereAndMsg(msg) or {}
    self.code  = tonumber(code) or 500
    self.msg   = info.msg
    self.file  = info.file
    self.line  = info.line
    self.stack = self:_parseBacktrace(debug_traceback())
    return false
end

function _error:_parseBacktrace(str)
    str = S_split(str, '\n')
    if not S_starts(str[1], 'stack traceback:') then
        return nil
    end

    local bt = {}
    for i = 3, #str do -- выкидываем "stack traceback:" и вызов самого _parseBacktrace()
        table_insert(bt, self:_splitErrorLineByWhereAndMsg(str[i]))
    end

    return bt
end

function _error:_splitErrorLineByWhereAndMsg(line)
    line = S_trim(line)
    local m = ngx_match(line, [[^(?<path>[^:]+):(?<line>[0-9]+):(?<msg>.*)$]], 'jo') or {}
    return {
        msg  = S_trim(m.msg or line),
        file = m.path or '',
        line = tonumber(m.line) or 0,
    }
end

function _error:place()
    local line = self.line and (':' .. self.line) or ''
    if self.file and (#self.file > 0) then
        return ' in ' .. self.file .. line
    else
        return ''
    end
end

local App = {}

function App:serve()
    ngx.ctx.estrela = self

    local logger = self.config.error_logger
    if logger then
        if type(logger) == 'string' then
            logger = require(logger):new()
        elseif type(logger) == 'function' then
            logger = logger()
        end
    end
    if logger then
        self.log = logger
    end

    self.req  = Request:new()
    self.resp = Response:new()
    self.error:clean()

    self.session = nil

    local pathPrefix = self.config:get('router.pathPrefix')
    if pathPrefix then
        self.router.path_prefix = pathPrefix
    end

    local with_ob = self.config:get('ob.active')
    local ob_level = 0

    self.subpath = setmetatable({}, { __mode = 'v', })
    self:_protcall(function()
        if with_ob then
            OB_start()
            ob_level = OB_levels()
        end

        if self.config:get('session.active') then
            local encdec = self.config:get('session.handler.encdec')
            if type(encdec) == 'function' then
                encdec = encdec()
            end
            assert(encdec, 'There are no defined encoder/decoder for session')

            local storage = self.config:get('session.storage.handler')
            if type(storage) == 'function' then
                storage = storage(self)
            end
            assert(storage, 'There are no defined storage for session')

            local SESSION = require(self.config:get('session.handler.handler'))

            self.session = SESSION:new(storage, encdec.encode, encdec.decode)
        end

        return self:_callTriggers(self.trigger.before_req) and self:_callRoutes()
    end)

    -- after_req триггеры вызываются даже в случае ошибки внутри before_req или роутах
    if next(self.trigger.after_req) then
        self:_protcall(function()
            return self:_callTriggers(self.trigger.after_req)
        end)
    end

    if self.error.code > 0 then
        if with_ob then
            -- при ошибке отбрасываем все ранее выведенное
            -- несбалансированность ob при этом не проверяем, т.к. она допустима при ошибках
            while OB_levels() >= ob_level do
                OB_finish()
            end
        end
        self:_callErrorCb()
    else
        if with_ob then
            if OB_levels() > ob_level then
                self.log.warn('OB is not balanced')
            end

            while OB_levels() >= ob_level do
                if not self.error.redirect then
                    OB_flush()
                end
                OB_finish()
            end
        end
    end

    if self.session then
        self.session:stop()
    end

    if self.error.redirect then
        return ngx.redirect(self.error.redirect.url, self.error.redirect.status)
    end
end

function App:defer(func, ...)
    if type(func) ~= 'function' then
        return nil, 'missing func'
    end
    table_insert(self.defers, {cb = func, args = {...}})
    return true
end

function App:abort(code, msg)
    self.error.aborted_code = code or 500
    return error(msg or '', 2)
end

function App:redirect(url, status)
    self.error.redirect = {
        url    = url,
        status = status or ngx.HTTP_MOVED_TEMPORARILY,
    }
    return self:abort(0)
end

function App:defaultErrorPage()
    local err = self.error

    self.resp.headers.content_type = 'text/html'

    if err.code > 0 then
        ngx.status = err.code
    end

    local html = {}

    if self.config.debug then
        local enc = S_htmlencode

        table_insert(html, table_concat{
            'Error #', err.code, ' <b>', enc(err.msg or ''), '</b> ', enc(err:place()), '<br/><br/>'
        })

        if type(err.stack) == 'table' then
            table_insert(html, 'Stack:<ul>')
            for _, bt in ipairs(err.stack) do
                table_insert(html, '<li>' .. enc(bt.file))
                if bt.line > 0 then
                    table_insert(html, ':' .. bt.line)
                end
                table_insert(html, ' ' .. enc(bt.msg))
                table_insert(html, '</li>')
            end
            table_insert(html, '</ul>')
        end
    end

    local res = self:_renderInternalTemplate(tostring(err.code), {
        code  = err.code,
        descr = table_concat(html),
    })

    if not res then
        -- полный ахтунг. не удалось вывести страницу с описанием ошибки
        return nil
    end

    return true
end

function App:forward(url)
    return {
        forward = url,
    }
end

-- @return bool
function App:_renderInternalTemplate(name, args)
    local path = path_join(env_get_root(), 'ngx', 'tmpl', name .. '.html')
    local fd = io_open(path, 'rb')
    if not fd then
        return false
    end

    local cont = fd:read('*all')
    fd:close()

    ngx.header.content_type = 'text/html'

    cont = ngx_gsub(
        cont,
        [[{{([.a-z]+)}}]],
        function(m)
            local val = args[m[1]] or assert(loadstring('local self = ...; return ' .. m[1]))(self) or ''
            return tostring(val)
        end,
        'jo'
    )

    return OB_print(cont)
end

function App:_protcall(func)
    self.error.aborted_code = nil
    return xpcall(
        func,
        function(err)
            self.log.err(err)
            local code = self.error.aborted_code and self.error.aborted_code or ngx.HTTP_INTERNAL_SERVER_ERROR
            return self.error:init(code, err)
        end
    )
end

function App:_callTriggers(triggers_list)
    for _, cb in ipairs(triggers_list) do
        local ok, res = self:_callRoute(cb)
        if not ok then
            return ok, res
        elseif res == true then
            break
        end
    end
    return true
end

function App:_callErrorCb()
    local errno = self.error.code

    local route = self.router:getByName(errno)
    if route then
        local ok, handled = self:_callRoute(route.cb)
        if not (ok and handled) then
            -- ошибка в обработчике ошибки, либо обработчик не стал сам обрабатывать ошибку
            return self:defaultErrorPage()
        end
        return ok
    else
        return self:defaultErrorPage()
    end
end

function App:_callDefers()
    local ok = true

    for _, defer in ipairs(self.defers) do
        local _ok, _ = self:_protcall(function()
            return defer.cb(unpack(defer.args))
        end)

        ok = ok and _ok
    end

    self.defers = {}
    return ok
end

function App:_callRoute(cb)
    self.defers = {}

    local ok, res = self:_protcall(function()
        return cb(self, self.req, self.resp)
    end)

    local def_ok, def_res = self:_callDefers()

    if ok and not def_ok then
        ok, res = def_ok, def_res
    end

    return ok, res
end

function App:_callRoutes()
    local ok = true

    local found = false

    local path = self.req.path
    if #self.subpath > 0 then
        path = self.subpath[#self.subpath].url
    end

    for route in self.router:route(path) do
        -- защита от рекурсии
        for _, sp in ipairs(self.subpath) do
            if sp.cb == route.cb then
                return self.error:init(ngx.HTTP_INTERNAL_SERVER_ERROR, 'Route recursion detected')
            end
        end

        self.route = route

        local _ok, res = self:_callRoute(route.cb)
        ok = ok and _ok

        local extras = _ok and (type(res) == 'table')
        local pass = _ok and (res == true)

        if not pass then
            found = true

            if extras then
                if res.forward then
                    local url = self.router:getFullUrl(res.forward)

                    table_insert(self.subpath, {url=url, cb=route.cb})
                    ok = self:_callRoutes()
                    self.subpath[#self.subpath] = nil
                end
            end

            break
        end
    end

    if not found then
        return self.error:init(ngx.HTTP_NOT_FOUND, 'Route is not found')
    end

    return ok
end

local M = {}

function M:new(routes)
    local A = {
        route   = nil,
        req     = nil,
        resp    = nil,
        session = nil,

        subpath = {}, -- для перенаправлений между роутами в пределах одного запроса

        error   = _error,

        log     = require('estrela.log.ngx'):new(),

        defers  = {},
        trigger = {
            before_req = {add = table_insert,},
            after_req  = {add = table_insert,},
        },

        config = setmetatable(
            {
                -- Отладочный режим. При ошибках выводится полный stacktrace
                debug = false,

                -- Буферизация вывода
                ob = {
                    active = true,
                },

                -- Сессии
                session = {
                    -- При неактивный сессиях app.session не инициализируется (app.session.start не доступна)
                    active = false,
                    -- Настройки хранилища сессионных данных
                    storage = {
                        handler = function()
                            local SHMEM = require('estrela.storage.engine.shmem')
                            return SHMEM:new('session_cache')
                        end,
                    },
                    -- Настройки обработчика сессий
                    handler = {
                        -- Стандартный обработчик, хранящий сессионный id в куках
                        handler = 'estrela.ngx.session.engine.common',
                        -- Имя ключа (чего либо), хранящего сессионый id
                        key_name = 'estrela_sid',
                        -- Префикс для всех ключей хранилища, используемых обработчиком сессий
                        storage_key_prefix = 'estrela_session:',
                        -- Время жизни блокировки сессионного ключа в хранилище
                        storage_lock_ttl = 10,
                        -- Максимальное время ожидания (сек) отпускания блокировки сессионного ключа в хранилище
                        storage_lock_timeout = 3,
                        -- Сервис сериализации для хранения сессионный данных в хранилище
                        encdec = function()
                            local json = require('cjson')
                            json.encode_sparse_array(true)
                            return json
                        end,
                        -- Настройки печеньки, в которой хранится сессионый id
                        -- Используется, если выбранный обработчик сессий работает через куки
                        cookie = {
                            params = { -- смотри app.response.COOKIE.empty
                                --ttl = 86400,
                                httponly = true,
                                path = '/',
                            },
                        },
                    },
                },

                -- Маршрутизация запросов
                router = {
                    -- Игнорируемый маршрутизатором префикс URL. На случай работы не из корня сайта.
                    pathPrefix = '/',
                },

                -- Альтернативный логер вместо nginx error_log файла.
                error_logger = nil,
            }, {
                __index = _config_private,
            }
        ),
    }

    for k, v in pairs(App) do
        A[k] = v
    end

    ngx.ctx.estrela = A

    A.error:clean()

    A.router = Router:new(routes)

    return A
end

setmetatable(M, {
    __call = function(self, routes)
        return self:new(routes)
    end,
})

return M
