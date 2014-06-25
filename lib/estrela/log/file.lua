local error = error
local string_gsub = string.gsub
local string_format = string.format
local os_date = os.date
local io_open = io.open
local table_concat = table.concat
local require = require

local M = {}

function M:new(path, fmt)
    local f = io_open(path, 'ab')
    if not f then
        return error('Cannot open log file '..path)
    end

    fmt = fmt or '%Y/%m/%d %H:%M:%S {LVL} [{MSG}] {BT}'

    local L = require('estrela.log.common'):new()

    L._write  = function(lvl, msg, bt)
        local line = os_date(fmt)
        local bt = string_gsub(bt, '\n', ' => ')
        local lvl_str = string_format('%-6s', L.level_names[lvl])
        local line = string_gsub(string_gsub(string_gsub(line, '{LVL}', lvl_str), '{MSG}', msg), '{BT}', bt)
        f:write(line, '\n')
        f:flush()
    end

    L.close = function()
        f:close()
        f = nil
    end

    return L
end

return M
