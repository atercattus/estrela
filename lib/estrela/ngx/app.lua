local OOP = require('estrela.oop.single')

local Router = require('estrela.ngx.router')
local Request = require('estrela.ngx.request')
local Response = require('estrela.ngx.response')
local S = require('estrela.util.string')

local _app = {
    _callErrorCb = function(self, errno)
        local route = self.router:getByName(errno)
        if route then
            return self:_callRoute(route.cb, errno)
        else
            return ngx.exit(errno)
        end
    end,

    _callDefers = function(self)
        for _,defer in ipairs(self.defers) do
            local ok, res = pcall(defer.cb, unpack(defer.args))
            if not ok then
                self.defers = {}
                self.error = res
                return self:_callErrorCb(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end
        end
        self.defers = {}
    end,

    _callFilters = function(self, filters_list)
        for _,cb in ipairs(filters_list) do
            if self:_callRoute(cb) == true then
                break
            end
        end
    end,

    _callRoute = function(self, cb, errno)
        self.defers = {}

        local ok, res = xpcall(
            function()
                return cb(self, self.req, self.resp)
            end,
            function(err)
                local err = self:_splitErrorLineByWhereAndMsg(err)
                err.stack = self:_parseBacktrace(debug.traceback())
                return setmetatable(err, {
                    __tostring = function(self) return self.msg end,
                })
            end
        )

        self:_callDefers()

        if ok then
            return res
        elseif errno == ngx.HTTP_INTERNAL_SERVER_ERROR then
            -- ошибка в обработчике ошибки. прерываем работу
            return ngx.exit(errno)
        else
            self.error = res
            return self:_callErrorCb(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
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
    end
}

return OOP.name 'ngx.app'.class {
    new = function(self, routes)
        self.router = Router(routes)
        self.route = nil
        self.req  = nil
        self.resp = nil
        self.error = {}
        self.defers = {}
        self.filter = {
            before_req = {add = table.insert,},
            after_req  = {add = table.insert,},
        }
    end,

    serve = function(self)
        self.req  = Request()
        self.resp = Response()
        self.error = ''

        local found = false
        local called = {before=false, after=false}
        for route in self.router:route(self.req.path) do
            found = true
            self.route = route

            if not called.before then
                self:_callFilters(self.filter.before_req)
                called.before = true
            end

            if not self:_callRoute(route.cb) then
                if not called.after then
                    self:_callFilters(self.filter.after_req)
                    called.after = true
                end

                break
            end
        end

        if not called.after then
            self:_callFilters(self.filter.after_req)
            called.after = true
        end

        if not found then
            return self:_callErrorCb(ngx.HTTP_NOT_FOUND)
        end
    end,

    defer = function(self, func, ...)
        if type(func) ~= 'function' then
            return nil, 'missing func'
        end
        table.insert(self.defers, {cb = func, args = {...}})
        return true
    end,

    __index__ = function(self, key)
        return _app[key]
    end,
}
