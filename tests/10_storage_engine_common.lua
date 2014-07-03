if ngx then
    return function(tester)
        local S = require('estrela.storage.engine.common'):new()

        local error_str

        xpcall(S.get, function(err) error_str = err end)

        assert(error_str == 'Not implemented')
    end
end
