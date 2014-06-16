local M = {}

-- *nix only

local S = require('estrela.util.string')

function M.split(path)
    local name, ext

    local slash_pos = S.rfind(path, '/')
    if slash_pos then
        name = path:sub(slash_pos + 1)
        path = path:sub(1, slash_pos)
    else
        path, name = '', path
    end

    local dot_pos = S.rfind(name, '.')
    ext = dot_pos and name:sub(dot_pos + 1) or ''

    return {
        path = path,
        name = name,
        ext = ext,
    }
end

function M.rel(base, path)
    -- path = /path/to/lua/folder/bootstrap.lua
    -- base = /path/to/lua/lib/estrela
    -- res  = (../../folder/bootstrap.lua, 2)
    local _path = S.split(S.rtrim(path, '/'), '/')
    local _base = S.split(S.rtrim(base, '/'), '/')

    local len = math.min(#_path, #_base)
    for p = 1, len do
        if _path[p] ~= _base[p] then
            len = p - 1
            break
        end
    end

    local base_tail_len = #_base - len
    return string.rep('../', base_tail_len) .. table.concat(_path, '/', len + 1), base_tail_len
end

function M.join(path, ...)
    local dirs = {...}
    for _,dir in ipairs(dirs) do
        path = path .. (dir:sub(#dir) ~= '/' and '/' or '') .. dir
    end
    return path
end

return M
