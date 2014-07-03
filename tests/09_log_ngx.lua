if ngx then
    return function(tester)
        local _ngx_log = ngx.log

        local called = false
        ngx.log = function(...)
            called = true
        end

        local N = require('estrela.log.ngx'):new()
        N.emerg('hello world#1')

        local called2 = false
        ngx.log = function(...)
            called2 = true
        end

        N.level = N.DISABLE
        N.emerg('hello world#2')

        ngx.log = _ngx_log

        assert(
            called and (not called2),
            'was called'
        )
    end
end
