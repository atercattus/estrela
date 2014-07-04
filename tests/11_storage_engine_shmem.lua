if ngx then
    local function get_mock()
        local mock = {
            _data = {},

            _mem_enough = true,
        }

        function mock:get(key)
            local data = self._data[key]
            if not data or ((data.expire > 0) and (data.expire < ngx.now())) then
                return nil
            end

            return data.data
        end

        function mock:get_stale(key)
            local data = self._data[key]
            return data and data.data or nil
        end

        function mock:set(key, value, ttl)
            if not self._mem_enough then
                return false, 'no memory'
            end

            ttl = ttl or 0

            self._data[key] = {
                data   = value,
                expire = (ttl > 0) and (ngx.now() + ttl) or 0,
            }

            return true
        end

        function mock:add(key, value, ttl)
            if self:get(key) then
                return false, 'exists'
            end

            return self:set(key, value, ttl)
        end

        function mock:replace(key, value, ttl)
            if not self:get(key) then
                return false, 'not found'
            end

            return self:set(key, value, ttl)
        end

        function mock:incr(key, value)
            local val = self:get(key)
            if not val then
                return false, 'not found'
            end

            val = tonumber(val)
            if not val then
                return nil, 'not a number'
            end

            val = val + value

            self._data[key].data = val
            -- expire не обновляется

            return val
        end

        function mock:delete(key)
            self._data[key] = nil
        end

        return mock
    end

    return function(tester)
        local shmem_name = tostring(os.time()) .. tostring(math.random())

        ngx.shared[shmem_name] = get_mock()

        local S = require('estrela.storage.engine.shmem'):new(shmem_name)

        local key = 'foo'
        local val = 42

        -- basic

        assert(
            S:get(key) == nil,
            'get nonexistent key'
        )

        assert(
            S:set(key, val) == true,
            'set w/o ttl'
        )

        assert(
            S:incr(key, 7) == 49,
            'incr +'
        )

        assert(
            S:incr(key, -7) == val,
            'incr -'
        )

        assert(
            S:incr(ngx.now(), 7) == false,
            'incr nonexistent key'
        )

        assert(
            S:get(key) == val,
            'get existent key'
        )

        assert(
            S:add(key, val .. val) == false,
            'add w/ existent key'
        )

        assert(
            S:replace(key, val .. val) == true,
            'replace w/ existent key'
        )

        assert(
            S:get(key) == val .. val,
            'get replaced key'
        )

        assert(
            S:set(key, val) == true,
            'set existent key'
        )

        assert(
            S:exists(key) == true,
            'exists existent key'
        )

        S:delete(key)

        assert(
            S:get(key) == nil,
            'get deleted key'
        )

        assert(
            S:exists(key) == false,
            'exists nonexistent key'
        )

        -- expires

        assert(
            S:set(key, val, 0.5) == true,
            'set w/ ttl'
        )

        assert(
            S:exists(key) == true,
            'exists existent key w/ ttl'
        )

        ngx.sleep(0.5)

        assert(
            S:get(key) == nil,
            'get existent key w/ ttl after ttl expires'
        )

        assert(
            S:get(key, true) == val,
            'get stale existent key w/ ttl after ttl expires'
        )

        -- no enough of memory
        ngx.shared[shmem_name]._mem_enough = false

        assert(
            S:set(key, val) == false,
            'set w/ no enough of memory'
        )

        ngx.shared[shmem_name] = nil
    end
end
