local debug = require('debug')
local debug_getinfo = debug.getinfo
local string_len = string.len

local M = {}

local path_split = require('estrela.util.path').split
local S_rtrim = require('estrela.util.string').rtrim

local _lib_root

function M.get_root()
    return _lib_root
end

local function _setup_env()
    local _path = debug_getinfo(1).source:sub(2)
    _path = S_rtrim(path_split(_path).path, [[/]])
    _lib_root = _path:sub(1, -string_len('/util')-1)
end

_setup_env()

return M
