local error = error
local debug_traceback = debug.traceback
local table_concat = table.concat
local table_insert = table.insert

local S = require('estrela.util.string')
local S_split = S.split
local S_trim = S.trim

local M = {}

function M:new()
    local L = {
        DEBUG  = 8,
        INFO   = 7,
        NOTICE = 6,
        WARN   = 5,
        ERR    = 4,
        CRIT   = 3,
        ALERT  = 2,
        EMERG  = 1,
    }

    L.level = L.DEBUG -- выводить все ошибки
    L.bt_level = L.WARN -- не выводить backtrace для некритичных ошибок

    L.level_names = {
        [L.DEBUG]  = 'DEBUG',
        [L.INFO]   = 'INFO',
        [L.NOTICE] = 'NOTICE',
        [L.WARN]   = 'WARN',
        [L.ERR]    = 'ERR',
        [L.CRIT]   = 'CRIT',
        [L.ALERT]  = 'ALERT',
        [L.EMERG]  = 'EMERG',
    }

    local function _get_bt(bt_lvl)
        if L.bt_level >= bt_lvl then
            local _bt = S_split(debug_traceback(), '\n')
            local bt = {}
            for i = 4, #_bt do
                table_insert(bt, S_trim(_bt[i]))
            end
            return table_concat(bt, '\n')
        else
            return ''
        end
    end

    local function _write(lvl, args)
        if L.level >= lvl then
            return L._write(lvl, table_concat(args), _get_bt(lvl))
        end
    end

    L._write = function(lvl, msg, bt) return error('Not implemented') end

    L.debug  = function(...) return _write(L.DEBUG,  {...}) end
    L.info   = function(...) return _write(L.INFO,   {...}) end
    L.notice = function(...) return _write(L.NOTICE, {...}) end
    L.warn   = function(...) return _write(L.WARN,   {...}) end
    L.err    = function(...) return _write(L.ERR,    {...}) end
    L.crit   = function(...) return _write(L.CRIT,   {...}) end
    L.alert  = function(...) return _write(L.ALERT,  {...}) end
    L.emerg  = function(...) return _write(L.EMERG,  {...}) end

    L.warning   = L.warn
    L.error     = L.err
    L.critical  = L.crit
    L.emergency = L.emerg

    return L
end

return M
