local M = {}

local function super_func(self, ...)
    local frame = debug.getinfo(2)
    return getmetatable(self).__base[frame.name](self, ...)
end

function M.class(name, struct, parent)
    if type(name) ~= 'string' then
        name, struct, parent = nil, name, struct
    end

    name = name or 'Cls'..tostring(cls):sub(10)

    struct = struct or {}

    local cls = {}

    setmetatable(cls, {
        __index = function(cls, key)
            if key == 'name' then
                return name
            elseif parent then
                return parent[key]
            end
        end,
        __newindex = function(tbl, key, val)
            if key ~= 'name' then
                rawset(tbl, key, val)
            end
        end,
        __call = function(cls, ...)
            local base = parent and parent() or nil

            local inst = {}

            setmetatable(inst, {
                __base = base,
                __index = function(self, name)
                    if name == 'super' then
                        return super_func
                    end
                end,
            })

            if base then
                for k,v in pairs(base) do
                    inst[k] = v
                end
            end

            for k,v in pairs(struct) do
                inst[k] = v
            end

            inst.__class = cls

            local new = inst.new
            if new then
                new(inst, ...)
            end

            return inst
        end,
    })

    return cls
end

function M.subclass(parent)
    return function(struct)
        return M.class(struct, parent)
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
