local ipairs = ipairs
local math_min = math.min
local table_concat = table.concat
local table_insert = table.insert

local S = require('estrela.util.string')
local S_find_last = S.find_last
local S_rtrim = S.rtrim
local S_trim = S.trim
local S_split = S.split

local M = {}

-- *nix only

function M.split(path)
    local name, ext

    local slash_pos = S_find_last(path, '/')
    if slash_pos then
        name = path:sub(slash_pos + 1)
        path = path:sub(1, slash_pos)
    else
        path, name = '', path
    end

    local dot_pos = S_find_last(name, '.')
    ext = dot_pos and name:sub(dot_pos + 1) or ''

    return {
        path = path,
        name = name,
        ext = ext,
    }
end

function M.rel(base, path)
    local base = S_trim(base, '/')
    local path = S_trim(path, '/')
    local _base = (#base > 0) and S_split(base, '/') or {}
    local _path = (#path > 0) and S_split(path, '/') or {}

    local rel = {}
    local common_len = 0
    for p = 1, math_min(#_path, #_base) do
        if _base[p] == _path[p] then
            common_len = p
        else
            break
        end
    end

    for _ = 1, (#_base - common_len) do
        table_insert(rel, '..')
    end

    for p = common_len + 1, #_path do
        table_insert(rel, _path[p])
    end

    rel = table_concat(rel, '/')

    return rel, (#_base - common_len)
end

function M.join(path, ...)
    local dirs = {...}
    if #dirs == 0 then
        return path
    end

    local path = {S_rtrim(path, '/')}

    for _, dir in ipairs(dirs) do
        table_insert(path, S_trim(dir, '/'))
    end

    return table_concat(path, '/')
end

return M
