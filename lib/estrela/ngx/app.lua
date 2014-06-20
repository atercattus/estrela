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

    _splitErrorLineByWhereAndMsg = function(self, line)
        line = S.trim(line)
        local m = ngx.re.match(line, [[^(?<path>[^:]+)(:(?<line>[0-9]+))?:\s(?<msg>.+)]], 'jo') or {}
        return {
            msg  = m.msg or line,
            file = m.path or nil,
            line = tonumber(m.line) or 0,
        }
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

    _protcall = function(self, func)
        return xpcall(
            func,
            function(err)
                local err = self:_splitErrorLineByWhereAndMsg(err)
                err.stack = self:_parseBacktrace(debug.traceback())

                setmetatable(err, {
                    __tostring = function(me) return string.format('%s:%d: %s', me.file, me.line, me.msg) end,
                })

                ngx.log(ngx.ERR, tostring(err))

                self.error = err
                self.errno = ngx.HTTP_INTERNAL_SERVER_ERROR
                return nil
            end
        )
    end,

    _callFilters = function(self, filters_list)
        for _,cb in ipairs(filters_list) do
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
        local errno = self.errno

        local route = self.router:getByName(errno)
        if route then
            local res = self:_callRoute(route.cb)

            if self.errno > 0 then
                -- ошибка в обработчике ошибки
                return self:sendInternalErrorPage(self.errno)
            end
            return res
        else
            return self:sendInternalErrorPage(errno)
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

        return ok
    end,

    _callRoutes = function(self)
        local ok = true
        local found = false
        for route in self.router:route(self.req.path) do
            found = true
            self.route = route

            local _ok, res = self:_callRoute(route.cb)
            ok = ok and _ok

            if not _ok or (res ~= true) then
                break
            end
        end

        if not found then
            self.errno = ngx.HTTP_NOT_FOUND
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

return OOP.name 'ngx.app'.class {
    new = function(self, routes)
        ngx.ctx.estrela = self

        self.router = Router(routes)
        self.route = nil
        self.req  = nil
        self.resp = nil
        self.session = nil
        self.error = {}
        self.errno = 0
        self.defers = {}
        self.filter = {
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
        self.error = {}
        self.errno = 0

        local CACHE = require(self.config:get('session.storage.handler', 'estrela.cache.engine.shmem'))
        local SESSION = require(self.config:get('session.handler.handler', 'estrela.ngx.session.engine.common'))
        self.SESSION = SESSION(CACHE())

        OB.start()

        self:_protcall(function()
            return     self:_callFilters(self.filter.before_req)
                   and self:_callRoutes()
                   and self:_callFilters(self.filter.after_req)
        end)

        self.SESSION:save()

        if self.errno > 0 then
            OB.finish() -- при  ошибке отбрасываем все ранее выведенное
            self:_callErrorCb()
        else
            OB.flush()
            OB.finish()
        end
    end,

    defer = function(self, func, ...)
        if type(func) ~= 'function' then
            return nil, 'missing func'
        end
        table.insert(self.defers, {cb = func, args = {...}})
        return true
    end,

    sendInternalErrorPage = function(self, errno, as_debug)
        errno = errno or 500
        ngx.status = errno

        local html = {}

        if type(self.error) == 'string' then
            self.error = {msg = self.error,}
        end

        if (as_debug or self.config.debug) and self.error.msg then
            local err = self.error
            local enc = S.htmlencode

            local place = err.file and ' in '..err.file..(err.line and ':'..err.line or '') or ''

            table.insert(html, '<b>'..enc(err.msg)..'</b> '..place..'<br/><br/>')

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

        local res = self:_renderInternalTemplate(tostring(errno), {
            code  = errno,
            descr = table.concat(html),
        })

        if not res then
            -- полный ахтунг. не удалось вывести страницу с описанием ошибки
            ngx.print('Ooops! Something went wrong')
            return nil
        end

        return true
    end,

    __index__ = function(self, key)
        return _app_private[key]
    end,
}
