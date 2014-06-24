local ngx_eof = ngx.eof
local ngx_print = ngx.print
local ngx_say = ngx.say

local COOKIE = require('estrela.ngx.response.cookie')

local M = {}

function M:new()
    return {
        headers = ngx.header,
        COOKIE  = COOKIE:new(),

        finish = function(self)
            return ngx_eof()
        end,

        write = function(self, ...)
            return ngx_print(...)
        end,

        writeln = function(self, ...)
            return ngx_say(...)
        end,
    }
end

return M
