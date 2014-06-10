local M = {}

function M.class(struct)
    struct = struct or {}

    local cls = {}

    setmetatable(cls, {
        __call = function(self, ...)
            local inst = {}

            for k,v in pairs(struct) do
                inst[k] = v
            end

            local new = inst.new
            if new then
                new(inst, ...)
            end

            return inst
        end,
    })

    return cls
end

return M
