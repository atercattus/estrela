local tests = {
    -- sprint
    {
        name = 'sprint_basic',
        code = function(tester, test)
            local sprint = require('estrela.io.pprint').sprint

            assert(
                sprint() == 'nil\n',
                test.name .. ' w/o params'
            )

            assert(
                sprint(nil) == 'nil\n',
                test.name .. ' nil'
            )

            assert(
                sprint('') == '""\n',
                test.name .. ' empty string'
            )

            assert(
                sprint(0) == '0\n',
                test.name .. ' number'
            )

            assert(
                sprint('hello') == '"hello"\n',
                test.name .. ' string'
            )

            assert(
                sprint({}) == '{\n}\n',
                test.name .. ' empty table'
            )

            assert(
                sprint({'hello', 42, 'world'}) == '{\n\t[1] = "hello",\n\t[2] = 42,\n\t[3] = "world",\n}\n',
                test.name .. ' table'
            )

            assert(
                sprint(true) == 'true\n',
                test.name .. ' boolean'
            )

            assert(
                sprint(ngx.null) == 'nil --[[userdata]]\n',
                test.name .. ' userdata'
            )

            -- nil --[[function: 0x41209210 .../../../tests/6_io_pprint.lua:10]]
            local res = [[^nil --\[\[function: 0x[0-9a-f]+ .*io_pprint\.lua:[0-9]+\]\]\s$]]

            assert(
                ngx.re.match(sprint(function() end), res),
                test.name .. ' function'
            )
        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
    },

    {
        name = 'sprint_compact',
        code = function(tester, test)
            local sprint = require('estrela.io.pprint').sprint

            assert(
                sprint(0, {compact=true}) == '0',
                test.name .. ' number'
            )

            assert(
                sprint({}, {compact=true}) == '{}',
                test.name .. ' empty table'
            )

            assert(
                sprint({'hello', 42, 'world'}, {compact=true}) == '{[1] = "hello",[2] = 42,[3] = "world",}',
                test.name .. ' table'
            )

        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
    },

    {
        name = 'sprint_max_depth',
        code = function(tester, test)
            local sprint = require('estrela.io.pprint').sprint

            local res = '{[1] = 1,[2] = {[1] = 2,[2] = {[1] = 3,[2] = 4,},[3] = 5,},[3] = 6,}'
            assert(
                sprint({1, {2, {3, 4}, 5}, 6}, {compact=true, max_depth=5}) == res,
                test.name .. ' max_depth > table depth'
            )

            local res = '{[1] = 1,[2] = {[1] = 2,[2] = nil --[[max_depth cutted]],[3] = 5,},[3] = 6,}'
            assert(
                sprint({1, {2, {3, 4}, 5}, 6}, {compact=true, max_depth=1}) == res,
                test.name .. ' max_depth < table depth'
            )

            local res = '{[1] = "a",[2] = {[{[1] = "b",[2] = nil --[[max_depth cutted]],}] = {[nil --[[max_depth cutted]]] = nil --[[max_depth cutted]],},},}'
            assert(
                sprint({'a', {[{'b', {'c'}}] = {[{'d'}] = {'e', 'f'}}}}, {compact=true, max_depth=2}) == res,
                test.name .. ' max_depth < table depth w/ tables as keys'
            )
        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
    },

    {
        name = 'sprint_func_pathes',
        code = function(tester, test)
            local sprint = require('estrela.io.pprint').sprint

            -- nil --[[function: 0x41209210]]
            local res = [[^nil --\[\[function: 0x[0-9a-f]+\]\]\s$]]

            assert(
                ngx.re.match(sprint(function() end, {func_pathes=false}), res),
                test.name
            )
        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
    },

    {
        name = 'sprint_func_patches_short',
        code = function(tester, test)
            local sprint = require('estrela.io.pprint').sprint

            local f = function() end

            assert(
                sprint(f, {func_patches_short=false}) ~= sprint(f, {func_patches_short=true}),
                test.name
            )
        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
    },

    {
        name = 'sprint_func_patches_short_rel',
        code = function(tester, test)
            local sprint = require('estrela.io.pprint').sprint

            local f = function() end

            assert(
                sprint(f, {func_patches_short_rel=100500}) == sprint(f, {func_patches_short=true}),
                test.name .. ' rel 100500'
            )

            assert(
                sprint(f, {func_patches_short_rel=0}) == sprint(f, {func_patches_short=false}),
                test.name .. ' rel 1'
            )
        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
    },

    -- print
    {
        name = '',
        code = function(tester, test)
            local pprint = require('estrela.io.pprint').print;

            -- с подменой writer'а
            (function()
                local data = {}
                local function writer(chunk)
                    table.insert(data, chunk)
                end

                pprint({'hello', 42, 'world'}, {compact=true, writer=writer})

                data = table.concat(data)

                assert(
                    data == '{[1] = "hello",[2] = 42,[3] = "world",}',
                    test.name .. ' w/ writer'
                )
            end)();

            -- стандартный вывод через ngx.print
            (function()
                local data = {}
                local _ngx_print = ngx.print
                ngx.print = function(chunk)
                    table.insert(data, chunk)
                end

                pprint({'hello', 42, 'world'}, {compact=true})

                ngx.print = _ngx_print

                data = table.concat(data)

                assert(
                    data == '{[1] = "hello",[2] = 42,[3] = "world",}',
                    test.name .. ' w/o writer'
                )
            end)();
        end,
        checker = function(tester, test, body, status, headers)
            return true
        end,
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
