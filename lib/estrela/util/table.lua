local coroutine_wrap = coroutine.wrap
local coroutine_yield = coroutine.yield
local getmetatable = getmetatable
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local table_concat = table.concat
local table_insert = table.insert
local type = type

local M = {}

local function wrap_gen_func(gen)
    local gen = coroutine_wrap(gen)

    return setmetatable({}, {
        __index = function(self, key)
            return (key == 'list') and M.list or nil
        end,
        __call = function(...)
            return gen(...)
        end,
    })
end

function M.push(tbl, ...)
    for _, v in ipairs{...} do
        table_insert(tbl, v)
    end

    return tbl
end

function M.clone(tbl)
    if type(tbl) ~= 'table' then
        return tbl
    end

    local copy = {}
    for k, v in pairs(tbl) do
        copy[M.clone(k)] = M.clone(v)
    end

    setmetatable(copy, M.clone(getmetatable(tbl)))

    return copy
end

function M.rep(tbl, times)
    local t = {}
    while times > 0 do
        table_insert(t, M.clone(tbl))
        times = times - 1
    end
    return t
end

function M.range(start, stop, step)
    if not stop then
        start, stop = 1, start
    end

    if not step then
        step = start <= stop and 1 or -1
    end

    return wrap_gen_func(function()
        for i = start, stop, step do
            coroutine_yield(i)
        end
    end)
end

function M.join(tbl, sep)
    return table_concat(tbl, sep)
end

function M.len(tbl)
    local cnt = 0
    for _, _ in pairs(tbl) do
        cnt = cnt + 1
    end
    return cnt
end

function M.list(smth)
    local l = {}
    for v in smth do
        table_insert(l, v)
    end
    return l
end

function M.contains(tbl, item)
    for _, v in pairs(tbl) do
        if v == item then
            return true
        end
    end
    return false
end

local MT = {
    __index = M,
    __add   = M.push,
    __mul   = M.rep,
}

setmetatable(M, {
    __call = function(cls, ...)
        return setmetatable({}, MT):push(...)
    end,
})

return M
