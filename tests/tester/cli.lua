local M = require('tests.tester.common')

local cookie_file_name = os.tmpname()

function M.exec(cmd, ignore_code)
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

function M.exec_by_lines(cmd)
    local out, err = M.exec(cmd)
    if out then
        local lines = M.split(M.trim(out), '\n')
        out = {}
        for _, line in ipairs(lines) do
            table.insert(out, M.trim(line))
        end
    end
    return out, err
end

function M.ls_tests(path)
    local lst, err = M.exec_by_lines('ls -1 ' .. path)
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

function M.http_req(url, args)
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

    local body, err = M.exec(req, true)
    if not body then
        return nil, err
    end

    local status, headers_or_err = M.parse_response_header(err)
    if not status then
        return nil, headers_or_err
    end

    return body, status, headers_or_err
end

function M.req(...)
    local body, status, headers = M.http_req(...)
    if headers[M.error_header_name] then
        return error(headers[M.error_header_name])
    else
        return body, status, headers
    end
end

function M.check(orig, got)
    if orig == got then
        return true
    else
        return false, string.format([[Expected: %s, got: %s]], M.prepare_string(orig), M.prepare_string(got))
    end
end

function M.remove_cookies()
    os.remove(cookie_file_name)
end

function M.multitest_cli(self, tests)
    for _, test in ipairs(tests) do
        local body, status, headers = self.req(self.url, {name = test.name})
        local ok = test.checker(self, test, body, status, headers)
        if ok == nil then
            assert(status and (status.code == 200), test.name)
        end
    end
    return true
end

return M
