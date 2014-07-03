if ngx then
    return function(tester)
        local levels = require('estrela.log.common'):new().level_names

        math.randomseed(os.time())

        for level_code, level_name in pairs(levels) do
            local tmpname = os.tmpname()

            local check = tostring(os.time()) .. tostring(math.random())

            local F = require('estrela.log.file'):new(tmpname, 'TESTER %Y/%m/%d %H:%M:%S {LVL} [{MSG}] {BT}')
            F._write(level_code, check, '')
            F.close()

            local fd = io.open(tmpname, 'rb')
            assert(fd, 'logfile exists')

            local cont = fd:read('*a')
            fd:close()

            os.remove(tmpname)

            -- TESTER 2014/07/03 18:17:08 EMERG   [/tmp/lua_FU3WuM] \n
            local re = string.format(
                [=[^TESTER \d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} %s\s+\[%s\]\s{2}$]=],
                level_name,
                check
            )

            assert(
                ngx.re.match(cont, re),
                'format ' .. level_name
            )
        end

        local tmpname = os.tmpname()

        local F = require('estrela.log.file'):new(tmpname);
        F.level = F.EMERG
        F.debug('hello')
        F.close()

        local fd = io.open(tmpname, 'rb')
        assert(fd, 'logfile exists#2')

        local cont = fd:read('*a')
        fd:close()

        os.remove(tmpname)

        assert(
            #cont == 0,
            'format error levels'
        )
    end
end
