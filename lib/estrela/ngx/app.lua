local OOP = require('estrela.oop.single')

local Router = require('estrela.ngx.router')
local Request = require('estrela.ngx.request')
local Response = require('estrela.ngx.response')
local S = require('estrela.util.string')
local ENV = require('estrela.util.env')
local PATH = require('estrela.util.path')
local OB = require('estrela.io.ob')

local _app_private = {
    -- @return bool
    _renderInternalTemplate = function(self, name, args)
        local path = PATH.join(ENV.get_root(), 'ngx', 'tmpl', name..'.html')
        local fd = io.open(path, 'rb')
        if not fd then
            return false
        end

        local cont = fd:read('*all')
        fd:close()

        ngx.header.content_type = 'text/html'

        cont = ngx.re.gsub(
            cont,
            [[{{([.a-z]+)}}]],
            function(m)
                local val = args[m[1]] or assert(loadstring('local self = ...; return '..m[1]))(self) or ''
                return tostring(val)
            end,
            'jo'
        )

        return ngx.print(cont)
    end,

    _protcall = function(self, func)
        self.error.aborted_code = nil
        return xpcall(
            func,
            function(err)
                ngx.log(ngx.ERR, err)
                local code = self.error.aborted_code and self.error.aborted_code or ngx.HTTP_INTERNAL_SERVER_ERROR
                self.error:init(code, err)
                return nil
            end
        )
    end,

    _callTriggers = function(self, triggers_list)
        for _,cb in ipairs(triggers_list) do
            local ok, res = self:_callRoute(cb)
            if not ok then
                return ok, res
            elseif res == true then
                break
            end
        end
        return true
    end,

    _callErrorCb = function(self)
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
    end,

    _callDefers = function(self)
        local ok = true

        for _,defer in ipairs(self.defers) do
            local _ok, res = self:_protcall(function()
                return defer.cb(unpack(defer.args))
            end)

            ok = ok and _ok
        end

        self.defers = {}
        return ok
    end,

    _callRoute = function(self, cb)
        self.defers = {}

        local ok, res  = self:_protcall(function()
            return cb(self, self.req, self.resp)
        end)

        local def_ok, def_res = self:_callDefers()

        if ok and not def_ok then
            ok, res = def_ok, def_res
        end

        return ok, res
    end,

    _callRoutes = function(self)
        local ok = true
        local found = false

        local path = self.req.path
        if #self.subpath > 0 then
            path = self.subpath[#self.subpath].url
        end

        for route in self.router:route(path) do
            -- защита от рекурсии
            for _,sp in ipairs(self.subpath) do
                if sp.cb == route.cb then
                    return error('Route recursion detected')
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

                        table.insert(self.subpath, {url=url, cb=route.cb})
                        ok = self:_callRoutes()
                        self.subpath[#self.subpath] = nil
                    end
                end

                break
            end
        end

        if not found then
            self.error:init(ngx.HTTP_NOT_FOUND, 'Route is not found')
            ok = false
        end

        return ok
    end,
}

local _config_private = {
    load = function(self, map)
        for k,v in pairs(map) do
            self[k] = v
        end
    end,

    get = function(self, path, default)
        local ok, res = xpcall(
            function()
                return assert(loadstring('local self = ...; return self.'..path))(self)
            end,
            function() end
        )
        return ok and res or default
    end,
}

local _error = {
    clean = function(self)
        self.code  = 0
        self.msg   = nil
        self.file  = nil
        self.line  = nil
        self.stack = nil
        self.aborted_code = nil -- используется для передачи кода ошибки из app:abort() в обработчик xpcall
    end,

    init = function(self, code, msg)
        local info = self:_splitErrorLineByWhereAndMsg(msg)
        self.code  = tonumber(code) or 500
        self.msg   = info.msg
        self.file  = info.file
        self.line  = info.line
        self.stack = self:_parseBacktrace(debug.traceback())
    end,

    _parseBacktrace = function(self, str)
        str = S.split(str, '\n')
        if not S.starts(str[1], 'stack traceback:') then
            return nil
        end

        local bt = {}
        for i = 3, #str do -- выкидываем "stack traceback:" и вызов самого _parseBacktrace()
            table.insert(bt, self:_splitErrorLineByWhereAndMsg(str[i]))
        end

        return bt
    end,

    _splitErrorLineByWhereAndMsg = function(self, line)
        line = S.trim(line)
        local m = ngx.re.match(line, [[^(?<path>[^:]+)(:(?<line>[0-9]+))?:\s(?<msg>.+)]], 'jo') or {}
        return {
            msg  = m.msg or line,
            file = m.path or nil,
            line = tonumber(m.line) or 0,
        }
    end,

    place = function(self)
        local line = self.line and (':' .. self.line) or ''
        return self.file and ' in ' .. self.file .. line or  ''
    end,
}

return OOP.name 'ngx.app'.class {
    new = function(self, routes)
        ngx.ctx.estrela = self

        self.router = Router(routes)
        self.route = nil
        self.req  = nil
        self.resp = nil
        self.session = nil

        self.subpath = {} -- для перенаправлений между роутами в пределах одного запроса

        self.error = _error
        self.error:clean()

        self.defers = {}
        self.trigger = {
            before_req = {add = table.insert,},
            after_req  = {add = table.insert,},
        }

        self.config = setmetatable({
            debug = false,
        }, {
            __index = function(me, key)
                return _config_private[key]
            end,
        })
    end,

    serve = function(self)
        self.req  = Request()
        self.resp = Response()
        self.error:clean()

        self.SESSION = nil
        if self.config:get('session.active') then
            local CACHE = require(self.config:get('session.storage.handler', 'estrela.cache.engine.shmem'))
            local SESSION = require(self.config:get('session.handler.handler', 'estrela.ngx.session.engine.common'))
            self.SESSION = SESSION(CACHE())
        end

        local pathPrefix = self.config:get('router.pathPrefix')
        if pathPrefix then
            self.router.path_prefix = pathPrefix
        end

        local with_ob = self.config:get('ob.active')
        if with_ob then
            OB.start()
        end

        self.subpath = {}
        self:_protcall(function()
            return     self:_callTriggers(self.trigger.before_req)
                   and self:_callRoutes()
                   and self:_callTriggers(self.trigger.after_req)
        end)

        if self.SESSION then
            self.SESSION:save()
        end

        if self.error.code > 0 then
            if with_ob then
                OB.finish() -- при  ошибке отбрасываем все ранее выведенное
            end
            self:_callErrorCb()
        else
            if with_ob then
                OB.flush()
                OB.finish()
            end
        end
    end,

    defer = function(self, func, ...)
        if type(func) ~= 'function' then
            return nil, 'missing func'
        end
        table.insert(self.defers, {cb = func, args = {...}})
        return true
    end,

    abort = function(self, code, msg)
        self.error.aborted_code = code
        return error(msg, 2)
    end,

    defaultErrorPage = function(self)
        local err = self.error

        self.resp.headers.content_type = 'text/html'

        if err.code > 0 then
            ngx.status = err.code
        end

        local html = {}

        if self.config.debug and err.msg then
            local enc = S.htmlencode

            table.insert(html, '<b>'..enc(err.msg)..'</b> '..enc(err:place())..'<br/><br/>')

            if type(err.stack) == 'table' then
                table.insert(html, 'Stack:<ul>')
                for i,bt in ipairs(err.stack) do
                    table.insert(html, '<li>'..enc(bt.file))
                    if bt.line > 0 then
                        table.insert(html, ':'..bt.line)
                    end
                    table.insert(html, ' '..enc(bt.msg))
                    table.insert(html, '</li>')
                end
                table.insert(html, '</ul>')
            end
        end

        local res = self:_renderInternalTemplate(tostring(err.code), {
            code  = err.code,
            descr = table.concat(html),
        })

        if not res then
            -- полный ахтунг. не удалось вывести страницу с описанием ошибки
            ngx.print('Ooops! Something went wrong')
            return nil
        end

        return true
    end,

    forward = function(self, url)
        return {
            forward = url,
        }
    end,

    __index__ = function(self, key)
        return _app_private[key]
    end,
}
