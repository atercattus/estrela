local ipairs = ipairs
local pairs = pairs
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring

local buf = {}

local _direct_print = ngx and ngx.print or io.write

local _orig_print, _orig_io_write, _orig_ngx_say, _orig_ngx_print

local M = {}

function M.print(...)
    if #buf == 0 then
        for _, v in pairs({...}) do
            _direct_print(tostring(v))
        end
    else
        local len = 0
        local _buf = buf[#buf]
        for _, v in pairs({...}) do
            local chunk = tostring(v)
            if _buf['cb'] then
                chunk = _buf['cb'](chunk)
            end
            len = len + #chunk
            table_insert(_buf['buf'], chunk)
        end
        _buf['len'] = _buf['len'] + len
    end
end

function M.println(...)
    M.print(...)
    M.print('\n')
end

function M.print_lua(...)
    for i, v in pairs({...}) do
        if i > 1 then
            M.print('\t')
        end
        M.print(v)
    end
    M.print('\n')
end

local function _set_hooks()
    _orig_print,    print    = print,    M.print_lua
    _orig_io_write, io.write = io.write, M.print

    if ngx then
        _orig_ngx_say,   ngx.say   = ngx.say,   M.println
        _orig_ngx_print, ngx.print = ngx.print, M.print
    end
end

local function _restore_hooks()
    print    = _orig_print
    io.write = _orig_io_write

    if ngx then
        ngx.say   = _orig_ngx_say
        ngx.print = _orig_ngx_print
    end
end

function M.start(cb)
    if #buf == 0 then
        _set_hooks()
    end

    buf[#buf + 1] = {
        buf = {},
        len = 0,
        cb  = cb,
    }
end

function M.finish()
    buf[#buf] = nil

    if #buf == 0 then
        _restore_hooks()
    end
end

function M.flush()
    if #buf > 0 then
        local b, cb = table_concat(buf[#buf]['buf']), buf[#buf]['cb']
        M.finish()
        M.print(b)
        M.start(cb)
    end
end

function M.flush_finish()
    if #buf > 0 then
        local b = table_concat(buf[#buf]['buf'])
        M.finish()
        M.print(b)
    end
end

function M.get()
    return (#buf > 0) and table_concat(buf[#buf]['buf']) or nil
end

function M.levels()
    return #buf
end

function M.len()
    return (#buf > 0) and buf[#buf]['len'] or nil
end

function M.clean()
    if #buf > 0 then
        buf[#buf]['buf'], buf[#buf]['len'] = {}, 0
    end
end

function M.status()
    if #buf == 0 then
        return {}
    end

    local res = {}

    for _,lvl in ipairs(buf) do
        table_insert(res, {
            len = lvl['len'],
            cb  = lvl['cb'],
        })
    end

    return res
end

return M
