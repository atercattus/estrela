local OOP = require('estrela.oop.single')

return OOP.name 'ngx.router'.class {
    new = function(self, routes)
        self.routes = routes
    end,

    route = function(self)
        return coroutine.wrap(function()
            for prefix, cb in pairs(self.routes) do
                coroutine.yield(prefix, cb)
            end
        end)
    end,
}
