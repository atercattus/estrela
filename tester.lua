--[[
location /estrela_test {
    content_by_lua_file $document_root/../lua/tester.lua;
}

$ luajit tester.lua 'http://ater.me/estrela_test' ./tests
]]

local function load_test(name)
    return require('tests.' .. name)
end

local tester_error_header_name = 'x_tester_error'

if ngx then
    xpcall(
        function()
            local test_name = ngx.var.arg_test
            if not test_name then
                return error('Name of test is not defined')
            end

            local json

            local tester = {}
            function tester.tbl_cmpx(t1, t2, iter, cmp, ignore_mt)
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

                        if not tester.tbl_cmp(mt1, mt2) then
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

            function tester.tbl_cmp(t1, t2, ignore_mt)
                return     tester.tbl_cmpx(t1, t2, pairs, tester.tbl_cmp, ignore_mt)
                       and tester.tbl_cmpx(t2, t1, pairs, tester.tbl_cmp, ignore_mt)
            end

            function tester.tbl_cmpi(t1, t2, ignore_mt)
                return     tester.tbl_cmpx(t1, t2, ipairs, tester.tbl_cmpi, ignore_mt)
                       and tester.tbl_cmpx(t2, t1, ipairs, tester.tbl_cmpi, ignore_mt)
            end

            function tester.je(...)
                if not json then
                    json = require('cjson')
                    json.encode_sparse_array(true)
                end
                return json.encode{...}
            end

            function tester.multitest_srv(self, tests)
                local name = ngx.var.arg_name
                assert(name, 'Test name is not specified')

                local test
                for _, t in ipairs(tests) do
                    if t.name == name then
                        test = t
                        break
                    end
                end
                assert(test, 'Test with name [' .. tostring(name) .. '] is not found')

                return test.code(self, test)
            end

            return load_test(test_name)(tester)
        end,

        function(err)
            ngx.status = ngx.HTTP_BAD_REQUEST
            if #err > 1024 then
                err = err:sub(1, 1021) .. '...'
            end
            ngx.header[tester_error_header_name] = err
            return ngx.exit(0)
        end
    )
else
    local cookie_file_name = os.tmpname()

    local function exec(cmd, ignore_code)
        local stdout_name, stderr_name = os.tmpname(), os.tmpname()
        local cmd = string.format('%s >%s 2>%s', cmd, stdout_name, stderr_name)
        local code = os.execute(cmd)

        local stdout_fd, stderr_fd = io.open(stdout_name, 'rb'), io.open(stderr_name, 'rb')
        local stdout_buf, stderr_buf

        if (ignore_code or (code == 0)) and stdout_fd then
            stdout_buf = stdout_fd:read('*a')
        end

        if stderr_fd then
            stderr_buf = stderr_fd:read('*a')
        end

        os.remove(stdout_name)
        os.remove(stderr_name)

        return stdout_buf, stderr_buf or ''
    end

    local function rtrim(str, chars)
        chars = chars or '%s'
        local res = str:gsub('['..chars..']+$', '')
        return res
    end

    local function ltrim(str, chars)
        chars = chars or '%s'
        local res = str:gsub('^['..chars..']+', '')
        return res
    end

    local function trim(str, chars)
        chars = chars or '%s'
        return ltrim(rtrim(str, chars), chars)
    end

    local function split(str, sep)
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

    local function exec_by_lines(cmd)
        local out, err = exec(cmd)
        if out then
            local lines = split(trim(out), '\n')
            out = {}
            for _, line in ipairs(lines) do
                table.insert(out, trim(line))
            end
        end
        return out, err
    end

    local function ls_tests(path)
        local lst, err = exec_by_lines('ls -1 ' .. path)
        if not lst then
            return lst, err
        end

        local tests = {}

        for _, file in ipairs(lst) do
            local m = string.match(file, [[^(.+).lua$]])
            if m then
                table.insert(tests, m)
            end
        end

        table.sort(tests)

        return tests
    end

    local function parse_response_header(header)
        local lines = split(trim(header), '\n')

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
            local line = trim(lines[i])
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

    local function http_req(url, args)
        local url = url

        if args then
            for k, v in pairs(args) do
                url = url .. '&' .. tostring(k) .. '=' .. tostring(v)
            end
        end

        local req = table.concat(
            {
                'wget -S -q -O /dev/stdout -T 5 -w 1 --no-cache --keep-session-cookies',
                '--load-cookies', cookie_file_name,
                '--save-cookies', cookie_file_name,
                '"' .. url .. '"'
            },
            ' '
        )

        local body, err = exec(req, true)
        if not body then
            return nil, err
        end

        local status, headers_or_err = parse_response_header(err)
        if not status then
            return nil, headers_or_err
        end

        return body, status, headers_or_err
    end

    local function prepare_string(s)
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

    if #arg < 2 then
        print('Usage: ' .. arg[0] .. ' <http_url> <path_to_tests>')
        return os.exit(1)
    end

    local url = arg[1]
    local dir = arg[2]

    local tests, err = ls_tests(dir)
    if not tests then
        return error(err)
    end

    local stats = {
        ok   = 0,
        fail = 0,
    }

    local tester = {
        url = '',
    }

    function tester.req(...)
        local body, status, headers = http_req(...)
        if headers[tester_error_header_name] then
            return error(headers[tester_error_header_name])
        else
            return body, status, headers
        end
    end

    function tester.check(orig, got)
        if orig == got then
            return true
        else
            return false, string.format([[Expected: %s, got: %s]], prepare_string(orig), prepare_string(got))
        end
    end

    function tester.multitest_cli(self, tests)
        for _, test in ipairs(tests) do
            local body, status, headers = self.req(self.url, {name = test.name})
            test.checker(self, test, body, status, headers)
        end
        return true
    end

    local max_test_name_len = 0
    for _, test_name in ipairs(tests) do
        max_test_name_len = math.max(max_test_name_len, #test_name)
    end

    local max_test_idx_digits = math.ceil(math.log10(#tests + 1e-5))

    local test_header_format = '#### Test #%-' .. max_test_idx_digits .. 'd %-' .. max_test_name_len .. 's - '

    for idx, test_name in ipairs(tests) do
        io.write(string.format(test_header_format, idx, test_name))

        tester.url = url .. '?test=' .. test_name

        local ok, res, descr = xpcall(
            function()
                local test = load_test(test_name)
                if type(test) ~= 'function' then
                    -- если нет реализации теста, то используем базовую заготовку
                    test = function(tester)
                        local body, status, headers = tester.req(tester.url)

                        local ok = status and (status.code == 200)
                        local err = headers and headers[tester_error_header_name] or nil

                        return ok, err
                    end
                end
                return test(tester)
            end,
            function(err)
                return err
            end
        )

        if ok and res then
            stats.ok = stats.ok + 1
            print('OK')
        else
            stats.fail = stats.fail + 1
            print('ERROR', descr and descr or res)
        end
    end

    local format = [[Results:
    Total:   %d
    Success: %d
    Failed:  %d
    ]]

    print(string.format(
        format,
        stats.ok + stats.fail,
        stats.ok,
        stats.fail
    ))

    os.remove(cookie_file_name)

    os.exit(stats.fail == 0 and 0 or 1)
end
