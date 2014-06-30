local error = error
local require = require
local tostring = tostring

local M = {}

function M:new(shared_var)
    if not shared_var or not ngx.shared[shared_var] then
        return error('There are no defined ngx.shared[' .. tostring(shared_var) .. ']')
    end

    local E = require('estrela.storage.engine.common'):new()

    function E:new()
        self.shmem = ngx.shared[shared_var]
        return self
    end

    function E:get(key, stale)
        local func = stale and self.shmem.get_stale or self.shmem.get
        return func(self.shmem, key)
    end

    function E:set(key, val, ttl)
        return self.shmem:set(key, val, ttl or 0)
    end

    function E:add(key, val, ttl)
        return self.shmem:add(key, val, ttl or 0)
    end

    function E:replace(key, val, ttl)
        return self.shmem:replace(key, val, ttl or 0)
    end

    function E:incr(key, by)
        return self.shmem:incr(key, by or 1)
    end

    function E:delete(key)
        return self.shmem:delete(key)
    end

    function E:exists(key)
        return self:get(key) ~= nil
    end

    return E:new()
end

return M
