local M = {}

M.error_header_name = 'x_tester_error'

local json

function M.rtrim(str, chars)
    chars = chars or '%s'
    local res = str:gsub('['..chars..']+$', '')
    return res
end

function M.ltrim(str, chars)
    chars = chars or '%s'
    local res = str:gsub('^['..chars..']+', '')
    return res
end

function M.trim(str, chars)
    chars = chars or '%s'
    return M.ltrim(M.rtrim(str, chars), chars)
end

function M.split(str, sep)
    if not string.find(str, sep, 1, true) then
        return {str}
    end

    local res = {}

    local prev_pos = 1
    while #res < #str - 1 do
        local pos, pos_t = string.find(str, sep, prev_pos, true)
        if not pos then
            res[#res + 1] = str:sub(prev_pos)
            prev_pos = #str + 1
            break
        end

        res[#res + 1] = str:sub(prev_pos, pos - 1)
        prev_pos = pos_t + 1
    end

    if prev_pos <= #str then
        res[#res + 1] = str:sub(prev_pos)
    end

    return res
end

function M.parse_response_header(header)
    local lines = M.split(M.trim(header), '\n')

    local ver, code, descr = string.match(lines[1], [[^HTTP/(%d.%d)%s(%d+)%s(.+)$]])
    if not ver or not code or not descr then
        return nil, 'Wrong response status line format'
    end

    local status = {
        version = ver,
        code    = tonumber(code),
        descr   = descr,
    }

    local headers = {}

    for i = 2, #lines do
        local line = M.trim(lines[i])
        local k, v = string.match(line, [[^([^:]+):%s*(.+)$]])
        if k and v then
            k = k:lower():gsub('-', '_')
            headers[k] = v
        else
            return nil, 'Wrong response header line format: ' .. line
        end
    end

    return status, headers
end

function M.prepare_string(s)
    local s_type = type(s)
    if s_type == 'nil' then
        return 'nil'
    elseif s_type == 'number' then
        return tostring(s)
    elseif s_type == 'string' then
        -- спец обработка \t и \n для сохранения ее в строке в текстовом формате
        s = string.gsub(s, '\t', [[\t]])
        s = string.gsub(s, '\n', [[\n]])
        s = string.format('%q', s)
        s = string.gsub(s, [[\\t]], [[\t]])
        s = string.gsub(s, [[\\n]], [[\n]])
        return s
    else
        return error('Unsupported type ' .. s_type)
    end
end

function M.tbl_cmpx(t1, t2, iter, cmp, ignore_mt)
    if type(t1) ~= 'table' or type(t2) ~= 'table' then
        return false
    end

    if not ignore_mt then
        local mt1 = getmetatable(t1)
        if type(mt1) == 'table' then
            local mt2 = getmetatable(t2)
            if type(mt2) ~= 'table' then
                return false
            end

            if not M.tbl_cmp(mt1, mt2) then
                return false
            end
        end
    end

    for k, v in iter(t1) do
        if type(v) == 'table' then
            if not cmp(t2[k], v, ignore_mt) then
                return false
            end
        elseif t2[k] ~= v then
            return false
        end
    end
    return true
end

function M.tbl_cmp(t1, t2, ignore_mt)
    return     M.tbl_cmpx(t1, t2, pairs, M.tbl_cmp, ignore_mt)
           and M.tbl_cmpx(t2, t1, pairs, M.tbl_cmp, ignore_mt)
end

function M.tbl_cmpi(t1, t2, ignore_mt)
    return     M.tbl_cmpx(t1, t2, ipairs, M.tbl_cmpi, ignore_mt)
           and M.tbl_cmpx(t2, t1, ipairs, M.tbl_cmpi, ignore_mt)
end

function M.je(...)
    if not json then
        json = require('cjson')
        json.encode_sparse_array(true)
    end
    return json.encode{...}
end

return M
