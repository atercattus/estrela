local M = {}

local path = require('estrela.util.path')

local _lib_root

function M.get_root()
    return _lib_root
end

local function _setup_env()
    local _path = debug.getinfo(1).source:sub(2)
    _lib_root = path.split(_path).path
end

_setup_env()

return M
