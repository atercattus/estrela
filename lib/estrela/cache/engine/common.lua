local error = error

local OOP = require('estrela.oop.single')

return OOP.name 'estrela.cache.engine.common'.class {
    get = function(self, key, stale)
        return error('Not implemented')
    end,

    set = function(self, key, val, ttl)
        return error('Not implemented')
    end,

    add = function(self, key, val, ttl)
        return error('Not implemented')
    end,

    replace = function(self, key, val, ttl)
        return error('Not implemented')
    end,

    incr = function(self, key, by)
        return error('Not implemented')
    end,

    delete = function(self, key)
        return error('Not implemented')
    end,

    exists = function(self, key)
        return error('Not implemented')
    end,
}
