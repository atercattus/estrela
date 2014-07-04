local demo_cookie = {
    name     = 'noname',
    value    = 'fake_value',
    path     = '/',
    httponly = true,
    secure   = true,
}

local function checker_demo_cookie(tester, test, body, status, headers)
    local parse_header_value = require('estrela.util.string').parse_header_value

    local cookie = headers['set_cookie']
    cookie = cookie and parse_header_value(cookie) or nil
    assert(cookie, test.name)

    table.sort(cookie['']) -- чтобы тест tester.tbl_cmpi ниже не зависел от порядка перечисления флагов

    assert(
        cookie[demo_cookie.name] == demo_cookie.value
                and cookie.path == demo_cookie.path
                and tester.tbl_cmpi(cookie[''], {'httponly', 'secure'}),
        test.name
    )
end

local tests = {
    -- empty
    {
        name = 'empty_wo_map',
        code = function(tester, test)
            local C = require('estrela.ngx.response.cookie'):new()

            local cookie = C:empty()

            assert(
                cookie.name and cookie.value and (type(cookie.set) == 'function'),
                test.name
            )
        end,
        checker = function(tester, test, body, status, headers)
        end,
    },

    {
        name = 'empty_with_map',
        code = function(tester, test)
            local C = require('estrela.ngx.response.cookie'):new()

            local cookie = C:empty(demo_cookie)
            cookie.set = nil -- удаляю метод, чтобы tbl_cmp не ругалась

            assert(
                tester.tbl_cmp(
                    cookie,
                    demo_cookie
                ),
                test.name
            )
        end,
        checker = function(tester, test, body, status, headers)
        end,
    },

    -- set
    {
        name = 'set_via_multi_params',
        code = function(tester, test)
            local C = require('estrela.ngx.response.cookie'):new()
            C:set(demo_cookie.name, demo_cookie.value, demo_cookie.expires, demo_cookie.path, demo_cookie.domain,
                demo_cookie.secure, demo_cookie.httponly
            )
        end,
        checker = checker_demo_cookie,
    },

    {
        name = 'set_wo_name',
        code = function(tester, test)
            local C = require('estrela.ngx.response.cookie'):new()

            local await_err = 'missing name or value'

            local ok, err = C:set()
            assert(
                (not ok) and (err == await_err),
                test.name .. 'w/o name'
            )

            local ok, err = C:set('')
            assert(
                (not ok) and (err == await_err),
                test.name .. 'empty name'
            )

            local ok, err = C:set('name')
            assert(
                (not ok) and (err == await_err),
                test.name .. 'name w/o value'
            )
        end,
        checker = function(tester, test, body, status, headers)
        end,
    },

    {
        name = 'set_via_map',
        code = function(tester, test)
            local C = require('estrela.ngx.response.cookie'):new()
            C:set(demo_cookie)
        end,
        checker = checker_demo_cookie,
    },

    {
        name = 'set_via_empty_set',
        code = function(tester, test)
            local C = require('estrela.ngx.response.cookie'):new()

            local cookie = C:empty()

            for k, v in pairs(demo_cookie) do
                cookie[k] = v
            end

            cookie:set()
        end,
        checker = checker_demo_cookie,
    },
}

if ngx then
    return function(tester)
        return tester:multitest_srv(tests)
    end
else
    return function(tester)
        return tester:multitest_cli(tests)
    end
end
