local M = {}

local _print = ngx and ngx.print or io.write

local buf = {}

function M.print(...)
    if #buf == 0 then
        for _, v in pairs({...}) do
            _print(tostring(v))
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
            table.insert(_buf['buf'], chunk)
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
    buf[#buf + 1] = {
        buf = {},
        len = 0,
        cb  = cb, -- реализовать
    }
end

function M.finish()
    buf[#buf] = nil
end

function M.get()
    if #buf > 0 then
        return table.concat(buf[#buf]['buf'])
    else
        return nil
    end
end

function M.levels()
    return #buf
end

function M.len()
    if #buf > 0 then
        return buf[#buf]['len']
    else
        return 0
    end
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
        return nil
    end

    local res = {}

    for _,lvl in ipairs(buf) do
        table.insert(res, {
            len = lvl['len'],
            cb  = lvl['cb'],
        })
    end

    return res
end

print    = M.print_lua
io.write = M.print

if ngx then
    ngx.say   = M.println
    ngx.print = M.print
end

return M
