local error = error

local M = {}

function M:new()
    local E = {}

    function E:new()
        return self
    end

    function E:get(key, stale)
        return error('Not implemented')
    end

    function E:set(key, val, ttl)
        return error('Not implemented')
    end

    function E:add(key, val, ttl)
        return error('Not implemented')
    end

    function E:replace(key, val, ttl)
        return error('Not implemented')
    end

    function E:incr(key, by)
        return error('Not implemented')
    end

    function E:delete(key)
        return error('Not implemented')
    end

    function E:exists(key)
        return error('Not implemented')
    end

    return E:new()
end

return M
