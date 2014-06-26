local COOKIE = require('estrela.ngx.response.cookie')

local OB = require('estrela.io.ob')
local OB_print = OB.print
local OB_println = OB.println

local M = {}

function M:new()
    return {
        headers = ngx.header,
        COOKIE  = COOKIE:new(),

        finish  = ngx.eof,
        write   = OB_print,
        writeln = OB_println,
    }
end

return M
