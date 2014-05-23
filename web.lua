if not ngx then
    return error('[lua-nginx-module](https://github.com/openresty/lua-nginx-module) is required')
end

local app = require('estrela.ngx.app')

return {
    App = app,
}

--[[
local estrela = require('estrela.web')

local app = estrela.App {
    ['/'] = function(self)
        ngx.say('Hello world')
    end,
}

app:serve()
]]
