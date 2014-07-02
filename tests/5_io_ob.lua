local tests = {
    {
        name = 'without_ob',
        code = function(tester)
            ngx.print 'ok'
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'ok', test.name)
        end,
    },

    -- print
    {
        name = 'print_wo_buff',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            OB.print('hello', 'world')
            OB.print(nil)
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld', test.name)
        end,
    },

    -- println
    {
        name = 'println_wo_buff',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            OB.println('hello', 'world')
            OB.println('traveler!')
            OB.println()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld\ntraveler!\n\n', test.name)
        end,
    },

    -- print_lua
    {
        name = 'print_lua_wo_buff',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            OB.print_lua('hello', 'world')
            OB.print_lua()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'hello\tworld\n\n', test.name)
        end,
    },

    -- start
    {
        name = 'start_wo_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                ngx.print 'world'
            -- without OB.finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'hello', test.name)
        end,
    },

    -- finish
    {
        name = 'start_with_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                ngx.print 'world'
            OB.finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'hello', test.name)
        end,
    },

    -- flush_finish
    {
        name = 'start_with_flush_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                ngx.print 'world'
            OB.flush_finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld', test.name)
        end,
    },

    {
        name = 'start_with_cb_with_flush_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.say 'hello'
            OB.start(function(chunk) return string.upper(chunk) end)
                ngx.print 'world'
            OB.flush_finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'hello\nWORLD', test.name)
        end,
    },

    {
        name = 'double_start_with_cb_with_flush_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start(function(chunk) return string.upper(chunk) end)
                ngx.print 'world'
                OB.start(function(chunk) return string.sub(chunk, 1, 2) end)
                    ngx.print 'traveler'
                OB.flush_finish()
            OB.flush_finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloWORLDTR', test.name)
        end,
    },

    {
        name = 'double_start_with_cb_with_only_one_flush_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start(function(chunk) return string.upper(chunk) end)
                ngx.print 'world'
                OB.start(function(chunk) return string.sub(chunk, 1, 2) end)
                    ngx.print 'traveler'
                OB.flush_finish()
            -- without OB.flush_finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'hello', test.name)
        end,
    },

    {
        name = 'start_with_double_flush_finish',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                ngx.print 'world'
            OB.flush_finish()

            OB.flush_finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld', test.name)
        end,
    },

    -- flush
    {
        name = 'start_with_flush',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                ngx.print 'world'
                OB.flush()
                ngx.print 'traveler'
            -- without OB.finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld', test.name)
        end,
    },

    -- get
    {
        name = 'get_after_start',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                print('world', 'traveler')
                io.write('!')
                local buf = OB.get()
            OB.flush_finish()

            ngx.print(buf)
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld\ttraveler\n!world\ttraveler\n!', test.name)
        end,
    },

    {
        name = 'get_before_start',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print(type(OB.get()))
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'nil', test.name)
        end,
    },

    -- levels
    {
        name = 'levels',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            local levels = {}
            table.insert(levels, OB.levels())
            OB.start()
                table.insert(levels, OB.levels())
                OB.start()
                    table.insert(levels, OB.levels())
                    OB.flush()
                    table.insert(levels, OB.levels())
                OB.finish()
                table.insert(levels, OB.levels())
            OB.flush_finish()
            table.insert(levels, OB.levels())

            ngx.print(table.concat(levels, ','))
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == '0,1,2,2,1,0', test.name)
        end,
    },

    -- len
    {
        name = 'len',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            local len = {}
            table.insert(len, OB.len())
            ngx.say(test.__prefix)
            table.insert(len, OB.len())
            OB.start()
                ngx.print 'a'
                table.insert(len, OB.len())
                ngx.print 'b'
                OB.start()
                    ngx.print 'c'
                    table.insert(len, OB.len())
                    ngx.print 'd'
                    OB.flush()
                    ngx.print 'e'
                    table.insert(len, OB.len())
                    ngx.print 'f'
                OB.finish()
                ngx.print 'g'
                table.insert(len, OB.len())
                ngx.print 'h'
            OB.flush_finish()
            ngx.print 'i'
            table.insert(len, OB.len())

            ngx.print(table.concat(len, ','))
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == test.__prefix .. '\nabcdghi1,1,1,5', test.name)
        end,
        __prefix = 'ufheforgofrygforgf7r9fyrurhyeguyrqeg7e',
    },

    -- clean
    {
        name = 'clean',
        code = function(tester, test)
            local OB = require('estrela.io.ob')
            ngx.print 'hello'
            OB.start()
                ngx.print 'world'
                OB.clean()
            OB.flush_finish()
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'hello', test.name)
        end,
    },

    -- status
    {
        name = 'status',
        code = function(tester, test)
            local OB = require('estrela.io.ob')

            local cb = function(chunk) return chunk end

            OB.start()
                ngx.print 'hello'
                OB.start(cb)
                    ngx.print 'world!'
                    local status = OB.status()
                OB.flush_finish()
            OB.flush_finish()

            assert(tester.tbl_cmp(status, {
                {
                    len = 5,
                    cb = nil,
                },
                {
                    len = 6,
                    cb = cb,
                },
            }))
            ngx.say 'hello'
        end,
        checker = function(tester, test, body, status, headers)
            assert(body == 'helloworld!hello\n', test.name)
        end,
    },
}

if ngx then
    return function(tester)
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

        return test.code(tester, test)
    end
else
    return function(tester)
        for _, test in ipairs(tests) do
            local body, status, headers = tester.req(tester.url, {name = test.name})
            test.checker(tester, test, body, status, headers)
        end
        return true
    end
end
