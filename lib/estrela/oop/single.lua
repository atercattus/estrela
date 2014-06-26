local debug = require('debug')
local debug_getinfo = debug.getinfo
local getmetatable = getmetatable
local pairs = pairs
local rawget = rawget
local rawset = rawset
local require = require
local setmetatable = setmetatable
local tostring = tostring
local type = type

local M = {}

local function super_func(self, ...)
    local frame = debug_getinfo(2)
    local mt = getmetatable(self)
    assert(mt and mt.__base, 'There are no super method')

    local func = mt.__base[frame.name]
    return func and func(self, ...) or nil
end

function M.class(name, struct, parent)
    if type(name) ~= 'string' then
        name, struct, parent = nil, name, struct
    end

    if type(parent) == 'string' then
        parent = require(parent)
    end

    local cls = {}

    name = name or ('Cls' .. tostring(cls):sub(10))

    struct = struct or {}

    -- создание новой инстанции класса без вызова конструкторов
    local function _create_inst()
        local base = parent and parent:create() or nil

        local inst = {}

        setmetatable(inst, {
            __base = base,
            __index = setmetatable(
                {
                    super = super_func,
                }, {
                    __index = function(_, key)
                        local idx_func = rawget(inst, '__index__')
                        if idx_func then
                            return idx_func(inst, key)
                        end
                    end,
                }
            ),
        })

        if base then
            for k, v in pairs(base) do
                inst[k] = v
            end
        end

        for k, v in pairs(struct) do
            inst[k] = v
        end

        inst.__class = cls

        return inst
    end

    setmetatable(cls, {
        __index = setmetatable(
            {
                __name   = name,
                name     = M.name,
                subclass = M.subclass,
                create   = _create_inst,
            }, {
                __index = function(_, key)
                    if parent then
                        return parent[key]
                    end
                end,
            }
        ),
        __newindex = function(tbl, key, val)
            if key ~= 'name' then
                rawset(tbl, key, val)
            end
        end,
        __call = function(cls, ...)
            local inst = cls:create()

            local new = inst.new
            if new then
                new(inst, ...)
            end

            return inst
        end,
    })

    return cls
end

function M.subclass(parent, name)
    return function(struct)
        return name and M.class(name, struct, parent) or M.class(struct, parent)
    end
end

function M.name(name)
    return {
        class = function(struct, parent)
            return M.class(name, struct)
        end,

        subclass = function(parent)
            return function(struct)
                return M.class(name, struct, parent)
            end
        end,
    }
end

return M
