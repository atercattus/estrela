local oop = require('estrela.oop.single')

local T = require('estrela.util.table')

return oop.name 'ngx.app'.class {

    new = function(self, routes)
        self.routes = routes
    end,

    serve = function(self)
        -- demo
        ngx.say('process url '..ngx.var.request_uri..' with '..T.len(self.routes)..' routes')
    end,
}
