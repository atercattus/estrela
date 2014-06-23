local ipairs = ipairs
local pairs = pairs
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring

local M = {}

local _print, _io_write, _ngx_say, _ngx_print = print, io.write, nil, nil
if ngx then
    _ngx_say, _ngx_print = ngx.say, ngx.print
end

local function _set_hooks()
    print    = M.print_lua
    io.write = M.print

    if ngx then
        ngx.say   = M.println
        ngx.print = M.print
    end
end

local function _restore_hooks()
    print    = _print
    io.write = _io_write

    if ngx then
        ngx.say   = _ngx_say
        ngx.print = _ngx_print
    end
end

local _direct_print = ngx and ngx.print or io.write

local buf = {}

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

function M.flush()
    if #buf > 0 then
        local b = M.get()
        M.finish()
        M.print(b)
        M.start()
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
