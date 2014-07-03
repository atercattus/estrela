if ngx then
    return function(tester)
        local L = require('estrela.log.common'):new();

        -- проверка наличия методов
        local methods = {'debug', 'info', 'notice', 'warn', 'err', 'crit', 'alert', 'emerg',}

        for _, method in ipairs(methods) do
            assert(L[method], method)

            local error_triggered = false
            xpcall(L[method], function() error_triggered = true end)
            assert(error_triggered, method .. ' error() call')
        end

        -- проверка наличия алиасов
        local methods = {warning='warn', error='err', critical='crit', emergency='emerg',}
        for alias, method in pairs(methods) do
            assert(L[alias] == L[method], alias)
        end
    end
end
