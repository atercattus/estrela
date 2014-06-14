local M = {}

local ENV = require('estrela.util.env')
local T = require('estrela.util.table')
local PATH = require('estrela.util.path')

local env_root = ENV.get_root()

local function sort_cb(a, b)
    if type(a) == 'number' and type(b) == 'number' then
        return a < b
    else
        return tostring(a) < tostring(b)
    end
end

local function prepare_string(s)
    -- спец обработка табуляции для сохранения ее в строке в форме \t
    s = s:gsub('\t', [[\t]])
    s = string.format('%q', s)
    s = s:gsub([[\\t]], [[\t]])
    return s
end

function M.sprint(v, opts)
    opts = opts or {}

    -- максимальная глубина обхода вложенных структур
    local max_depth = tonumber(opts.max_depth) or 100
    -- компактный вывод (без табуляций, новых строк)
    local compact = opts.compact
    -- выводить ли для функций место (файл:строка) их объявления
    local func_pathes = opts.func_pathes == nil and true or opts.func_pathes
    -- выводить ли сокращенные (относительные) пути при func_pathes
    local func_patches_short = opts.func_patches_short == nil and true or opts.func_patches_short
    -- на сколько уровней вверх по файловой системе можно подниматься, если функция была объявлена выше корня фреймворка
    local func_patches_short_rel = tonumber(opts.func_patches_short_rel) or 4

    local key_opts = T.clone(opts)
    key_opts.compact = true

    local result = {}

    local visited = {}

    local function _pretty_print(name, v, path)

        local prefix = compact and '' or string.rep('\t', #path)

        table.insert(result, prefix)
        if #name > 0 then
            table.insert(result, name .. ' ')
        end

        local type_v = type(v)
        if type_v == 'string' then
            table.insert(result, prepare_string(v))
        elseif type_v == 'number' or type_v == 'boolean' then
            table.insert(result, tostring(v))
        elseif type_v == 'table' then
            local table_id = tostring(v)

            if visited[table_id] then
                table.insert(result, 'nil --[[recursion to ' .. visited[table_id] .. ']]')
            else
                visited[table_id] = table.concat(path, '.')

                local keys = {}
                local only_numbers = true
                for key, _ in pairs(v) do
                    table.insert(keys, key)
                    only_numbers = only_numbers and (type(key) == 'number')
                end

                table.sort(keys, only_numbers and nil or sort_cb)

                table.insert(result, compact and '{' or '{\n')
                for _, key in pairs(keys) do
                    local _key
                    if type(key) == 'string' then
                        _key = prepare_string(tostring(key))
                    elseif type(key) == 'number' then
                        _key = tostring(key)
                    else
                        local _max_depth = key_opts.max_depth
                        key_opts.max_depth = max_depth - #path
                        _key = M.sprint(key, key_opts)
                        key_opts.max_depth = _max_depth
                    end
                    table.insert(path, _key)
                    _pretty_print('[' .. _key .. '] =', v[key], path)
                    path[#path] = nil
                end
                table.insert(result, prefix .. '}')
            end
        elseif v == nil then
            table.insert(result, 'nil')
        else
            local _v
            if type_v == 'function' then
                if func_pathes then
                    local func_info = debug.getinfo(v)
                    local path = func_info.short_src
                    if func_patches_short then
                        if path:find(env_root, 1, true) == 1 then
                            path = '...' .. path:sub(env_root:len()+1)
                        elseif func_patches_short_rel > 0 then
                            local _path, _rel_len = PATH.rel(env_root, path)
                            if _rel_len <= func_patches_short_rel then
                                path = '.../' .. _path
                            end
                        end
                    end
                    local line = func_info.linedefined
                    line = (line >= 0) and (':' .. line) or ''

                    _v = tostring(v) .. ' ' .. path .. line
                else
                    _v = tostring(v)
                end
            else
                _v = type_v
            end
            table.insert(result, 'nil --[[' .. _v .. ']]')
        end

        if #path > 0 then
            table.insert(result, ',')
        end

        if not compact then
            table.insert(result, '\n')
        end
    end

    _pretty_print('', v, {})

    return table.concat(result)
end

function M.print(v, opts)
    opts = opts or {}
    (opts.writer or io.write)(M.sprint(v, opts))
end

return M
