local M = {}

local S = require('estrela.util.string')

function M.split(path)
    local name, ext

    local slash_pos = S.rfind(path, '/') -- *nix only
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

return M
