local OOP = require('estrela.oop.single')

local Router = require('estrela.ngx.router')

return OOP.name 'ngx.app'.class {

    new = function(self, routes)
        self.router = Router(routes)
    end,

    serve = function(self)
        self.url = ngx.var.request_uri

        for prefix, cb in self.router:route() do
            if cb(self, prefix) then
                break
            end
        end
    end,
}
