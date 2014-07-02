if ngx then
    return function(tester)

        -- get_root
        (function()
            -- monkey patching :)
            local debug = require('debug')
            debug.getinfo = function()
                return {
                    source = '@/path/to/util/env.lua',
                }
            end

            local E = require('estrela.util.env')

            assert(
                E.get_root() == '/path/to',
                'get_root'
            )
        end)();
    end
end
