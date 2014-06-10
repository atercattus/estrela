local M = {}

local PATH = require('estrela.util.path')
local S = require('estrela.util.string')

local _lib_root

function M.get_root()
    return _lib_root
end

local function _setup_env()
    local _path = debug.getinfo(1).source:sub(2)
    _path = S.rtrim(PATH.split(_path).path, [[/]])
    _lib_root = _path:sub(1, -string.len('/util')-1)
end

_setup_env()

return M
