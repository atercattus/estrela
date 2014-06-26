local error = error
local string_gsub = string.gsub

local ngx_log = ngx.log

local M = {}

function M:new()
    local L = require('estrela.log.common'):new()

    L._write  = function(lvl, msg, bt)
        local bt = string_gsub(bt, '\n', ' => ')
        return ngx_log(lvl, msg, ', backtrace: ', bt)
    end

    return L
end

return M
