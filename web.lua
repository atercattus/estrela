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
    ['/'] = function(app)
        ngx.say('Hello world')
    end,

    [{account = '/:name'}] = function(app, name)
        name = name or ''
        ngx.say('Hello, '..tostring(name))
        return true
    end,
}

app:serve()
]]
