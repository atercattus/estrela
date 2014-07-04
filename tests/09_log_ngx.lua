if ngx then
    return function(tester)
        local _ngx_log = ngx.log

        local called = false
        ngx.log = function(...)
            called = true
        end

        local N = require('estrela.log.ngx'):new()
        N.emerg('hello world#1')

        local called2 = called

        N.level = N.DISABLE
        called = false
        N.emerg('hello world#2')

        ngx.log = _ngx_log

        assert(
            called2 and (not called),
            'was called'
        )
    end
end
