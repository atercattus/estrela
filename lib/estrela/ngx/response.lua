local OOP = require('estrela.oop.single')

return OOP.name 'ngx.response'.class {
    new = function(self)
        self.headers = ngx.header
    end,
}
