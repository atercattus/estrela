local M = {}

local function super_func(self, ...)
    local frame = debug.getinfo(2)
    return getmetatable(self).__base[frame.name](self, ...)
end

function M.class(name, struct, parent)
    if type(name) ~= 'string' then
        name, struct, parent = nil, name, struct
    end

    local cls = {}

    name = name or 'Cls'..tostring(cls):sub(10)

    struct = struct or {}

    -- создание новой инстанции класса без вызова конструкторов
    local function _create_inst()
        local base = parent and parent:create() or nil

        local inst = {}

        setmetatable(inst, {
            __base = base,
            __index = function(self, key)
                if key == 'super' then
                    return super_func
                else
                    local idx_func = rawget(self, '__index__')
                    if idx_func then
                        return idx_func(self, key)
                    end
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

        return inst
    end

    setmetatable(cls, {
        __index = function(cls, key)
            if key == '__name' then
                return name
            elseif key == 'name' then
                return M.name
            elseif key == 'subclass' then
                return M.subclass
            elseif key == 'create' then
                return _create_inst
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
