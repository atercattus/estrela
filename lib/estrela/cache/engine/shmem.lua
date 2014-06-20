local OOP = require('estrela.oop.single')

return OOP.subclass 'estrela.cache.engine.common' {
    new = function(self)
        local app = ngx.ctx.estrela

        local shared_var = app.config:get('session.storage.shmem.key')

        if not shared_var or not ngx.shared[shared_var] then
            return error('There are no defined ngx.shared['..tostring(shared_var)..']')
        end

        self:super()

        self.shmem = ngx.shared[shared_var]
    end,

    get = function(self, key, stale)
        local func = stale and self.shmem.get_stale or self.shmem.get
        return func(self.shmem, key)
    end,

    set = function(self, key, val, ttl)
        return self.shmem:set(key, val, ttl or 0)
    end,

    add = function(self, key, val, ttl)
        return self.shmem:add(key, val, ttl or 0)
    end,

    replace = function(self, key, val, ttl)
        return self.shmem:replace(key, val, ttl or 0)
    end,

    incr = function(self, key, by)
        return self.shmem:incr(key, by or 1)
    end,

    delete = function(self, key)
        return self.shmem:delete(key)
    end,

    exists = function(self, key)
        return self:get(key) ~= nil
    end,
}
