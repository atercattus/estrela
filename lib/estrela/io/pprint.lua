local M = {}

local ENV = require('estrela.util.env')

local envRoot = ENV.get_root()

local function sort_cb(a, b)
    if type(a) == 'number' and type(b) == 'number' then
        return a < b
    else
        return tostring(a) < tostring(b)
    end
end

function M.print(v, max_depth, writer)

    max_depth = tonumber(depth) or 100
    writer = writer or io.write

    local visited = {}

    local function _prepare_string(s)
        -- спец обработка табуляции для сохранения ее в строке в форме \t
        s = s:gsub('\t', [[\t]])
        s = string.format('%q', s)
        s = s:gsub([[\\t]], [[\t]])
        return s
    end

    local function _pretty_print(name, v, path)

        local prefix = string.rep('\t', #path)

        writer(prefix)
        if name:len() > 0 then
            writer(name, ' ')
        end

        local type_v = type(v)
        if type_v == 'string' then
            writer(_prepare_string(v))
        elseif type_v == 'number' then
            writer(v)
        elseif type_v == 'boolean' then
            writer(tostring(v))
        elseif type_v == 'table' then
            local table_id = tostring(v)

            if visited[table_id] then
                writer('nil --[[recursion to @'..visited[table_id]..']]')
            else
                visited[table_id] = table.concat(path, '.', 2)

                local keys = {}
                local only_numbers = true
                for key, _ in pairs(v) do
                    table.insert(keys, key)
                    only_numbers = only_numbers and (type(key) == 'number')
                end

                if only_numbers then
                    table.sort(keys)
                else
                    table.sort(keys, sort_cb)
                end

                writer('{\n')
                for _, key in pairs(keys) do
                    local _key = _prepare_string(tostring(key)) -- ToDo: поддержка не строковых ключей
                    table.insert(path, _key)
                    _pretty_print(_key..' =', v[key], path)
                    path[#path] = nil
                end
                writer(prefix, '}')
            end
        elseif v == nil then
            writer('nil')
        else
            local _v
            if type_v == 'function' then
                local func_info = debug.getinfo(v)
                local path = func_info.short_src
                if path:find(envRoot, 1, true) == 1 then
                    path = path:sub(envRoot:len()+1)
                end
                local line = func_info.linedefined
                line = (line >= 0) and (':' .. line) or ''

                _v = tostring(v) .. ' ' .. path .. line
            else
                _v = type_v
            end
            writer('nil --[[', _v, ']]')
        end

        if #path > 0 then
            writer(',')
        end

        writer('\n')
    end

    _pretty_print('', v, {})
end

return M
