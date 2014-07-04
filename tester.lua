--[[
location /estrela_test {
    content_by_lua_file $document_root/../lua/tester.lua;
}

$ luajit tester.lua 'http://ater.me/estrela_test' ./tests
]]

local function load_test(name)
    return require('tests.' .. name)
end

if ngx then
    return xpcall(
        function()
            local test_name = ngx.var.arg_test
            if not test_name then
                return error('Name of test is not defined')
            end

            local tester = require('tests.tester.ngx')

            return load_test(test_name)(tester)
        end,

        function(err)
            ngx.status = ngx.HTTP_BAD_REQUEST
            if #err > 1024 then
                err = err:sub(1, 1021) .. '...'
            end
            ngx.header[M.error_header_name] = err
            return ngx.exit(0)
        end
    )
else
    package.path = './lib/?.lua;' .. package.path

    if #arg < 2 then
        print('Usage: ' .. arg[0] .. ' <http_url> <path_to_tests>')
        return os.exit(1)
    end

    local url = arg[1]
    local dir = arg[2]

    local tester = require('tests.tester.cli')

    local tests, err = tester.ls_tests(dir)
    if not tests then
        return error(err)
    end

    local stats = {
        ok   = 0,
        fail = 0,
    }

    local max_test_name_len = 0
    for _, test_name in ipairs(tests) do
        max_test_name_len = math.max(max_test_name_len, #test_name)
    end

    local max_test_idx_digits = math.ceil(math.log10(#tests + 1e-5))

    local test_header_format = '#### Test #%-' .. max_test_idx_digits .. 'd %-' .. max_test_name_len .. 's - '

    for idx, test_name in ipairs(tests) do
        io.write(string.format(test_header_format, idx, test_name))

        tester.url = url .. '?test=' .. test_name

        tester.remove_cookies()

        local ok, res, descr = xpcall(
            function()
                local test = load_test(test_name)
                if type(test) ~= 'function' then
                    -- если нет реализации теста, то используем базовую заготовку
                    test = function(tester)
                        local body, status, headers = tester.req(tester.url)

                        local ok = status and (status.code == 200)
                        local err = headers and headers[tester.error_header_name] or nil

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

    tester.remove_cookies()

    return os.exit(stats.fail == 0 and 0 or 1)
end
