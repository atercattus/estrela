local OOP = require('estrela.oop.single')

local Router = require('estrela.ngx.router')
local Request = require('estrela.ngx.request')
local Response = require('estrela.ngx.response')

return OOP.name 'ngx.app'.class {
    new = function(self, routes)
        self.router = Router(routes)
        self.route = nil
        self.req  = nil
        self.resp = nil
        self.error = ''
    end,

    serve = function(self)
        self.req  = Request()
        self.resp = Response()
        self.error = ''

        local found = false
        for route in self.router:route(self.req.path) do
            found = true
            self.route = route
            if not self:_callRoute(route.cb) then
                break
            end
        end

        if not found then
            return self:_callErrorCb(ngx.HTTP_NOT_FOUND)
        end
    end,

    _callErrorCb = function(self, errno)
        local route = self.router:getByName(errno)
        if route then
            return self:_callRoute(route.cb, errno)
        else
            return ngx.exit(errno)
        end
    end,

    _callRoute = function(self, cb, errno)
        local ok, res = pcall(cb, self)
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
}
