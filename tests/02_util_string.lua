if ngx then
    return function(tester)
        local S = require('estrela.util.string');

        local str = 'hello world yep'

        -- find_first
        (function()
            assert(
                S.find_first(str, 'w') == 7,
                'find_first uniq [sub]'
            )

            assert(
                S.find_first(str, 'W') == nil,
                'find_first case sensitivity'
            )

            assert(
                S.find_first(str, 'l') == 3,
                'find_first ordinary [sub]'
            )

            assert(
                S.find_first(str, 'l', 3) == 3,
                'find_first with [start]'
            )

            assert(
                S.find_first(str, 'l', 6) == 10,
                'find_first with [start] after first appearance'
            )

            assert(
                S.find_first(str, 'l', 1, 3) == 3,
                'find_first with [stop]'
            )

            assert(
                S.find_first(str, 'l', 1, 2) == nil,
                'find_first with [stop] before first appearance'
            )

            assert(
                S.find_first(str, 'yep') == 13,
                'find_first multichar [sub]'
            )

            assert(
                S.find_first(str, 'yep!') == nil,
                'find_first over-tail check'
            )
        end)();

        -- find_last
        (function()
            assert(
                S.find_last(str, 'w') == 7,
                'find_last uniq [sub]'
            )

            assert(
                S.find_last(str, 'W') == nil,
                'find_last case sensitivity'
            )

            assert(
                S.find_last(str, 'l') == 10,
                'find_last ordinary [sub]'
            )

            assert(
                S.find_last(str, 'l', 3) == 10,
                'find_last with [start]'
            )

            assert(
                S.find_last(str, 'l', 1, 9) == 4,
                'find_last with [stop] before last appearance'
            )

            assert(
                S.find_last(str, 'l', 1, 3) == 3,
                'find_last with [stop]'
            )

            assert(
                S.find_last(str, 'l', 12) == nil,
                'find_last with [start] after last appearance'
            )

            assert(
                S.find_last(str, 'yep') == 13,
                'find_last multichar [sub]'
            )

            assert(
                S.find_last(str, 'yep!') == nil,
                'find_last over-tail check'
            )
        end)();

        -- split
        (function()
            assert(
                tester.tbl_cmpi(
                    S.split('hello'),
                    {'h', 'e', 'l', 'l', 'o'}
                ),
                'split w/o [sep]'
            )

            assert(
                tester.tbl_cmpi(
                    S.split('hello', ''),
                    {'h', 'e', 'l', 'l', 'o'}
                ),
                'split with empty [sep]'
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, '|'),
                    {str}
                ),
                'split with nonexistent [sep]'
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, ' '),
                    {'hello', 'world', 'yep'}
                ),
                [[split with [sep] = ' ']]
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, ' ', 1),
                    {str}
                ),
                [[split with [maxsplit] = 1]]
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, ' ', 2),
                    {'hello', 'world yep'}
                ),
                [[split with [maxsplit] = 2]]
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, ' ', 42),
                    {'hello', 'world', 'yep'}
                ),
                [[split with [maxsplit] = 42]]
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str .. ' ', ' '),
                    {'hello', 'world', 'yep', ''}
                ),
                [[split with empty section]]
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, '%s', nil, true),
                    {'hello', 'world', 'yep'}
                ),
                [[split with regex [sep] = '%s']]
            )

            assert(
                tester.tbl_cmpi(
                    S.split(str, '%s', nil, true),
                    {'hello', 'world', 'yep'}
                ),
                [[split with regex [sep] = '%s']]
            )

            assert(
                tester.tbl_cmpi(
                    S.split('hello world! yep:)', '%W+', nil, true),
                    {'hello', 'world', 'yep', ''}
                ),
                [[split with regex [sep] = '%W+']]
            )
        end)();

        -- ltrim
        (function()
            assert(
                S.ltrim(str) == str,
                'ltrim w/o spaces'
            )

            assert(
                S.ltrim(' ' .. str) == str,
                'ltrim w/ left spaces'
            )

            assert(
                S.ltrim(str .. ' ') == str .. ' ',
                'ltrim w/ right spaces'
            )

            assert(
                S.ltrim(' ' .. str .. ' ') == str .. ' ',
                'ltrim w/ left and right spaces'
            )

            assert(
                S.ltrim(' \r\n\v' .. str .. ' \r\n\v') == str .. ' \r\n\v',
                'ltrim w/ special chars'
            )

            assert(
                S.ltrim(str, 'helo ') == 'world yep',
                'ltrim w/ [chars]'
            )

            assert(
                S.ltrim(str, '') == str,
                'ltrim w/ empty [chars]'
            )
        end)();

        -- rtrim
        (function()
            assert(
                S.rtrim(str) == str,
                'rtrim w/o spaces'
            )

            assert(
                S.rtrim(' ' .. str) == ' ' .. str,
                'rtrim w/ left spaces'
            )

            assert(
                S.rtrim(str .. ' ') == str,
                'rtrim w/ right spaces'
            )

            assert(
                S.rtrim(' ' .. str .. ' ') == ' ' .. str,
                'rtrim w/ left and right spaces'
            )

            assert(
                S.rtrim(' \r\n\v' .. str .. ' \r\n\v') == ' \r\n\v' .. str,
                'rtrim w/ special chars'
            )

            assert(
                S.rtrim(str, 'yepdlrow ') == 'h',
                'rtrim w/ [chars]'
            )

            assert(
                S.rtrim(str, '') == str,
                'rtrim w/ empty [chars]'
            )
        end)();

        -- trim
        (function()
            assert(
                S.trim(str) == str,
                'trim w/o spaces'
            )

            assert(
                S.trim(' ' .. str) == str,
                'trim w/ left spaces'
            )

            assert(
                S.trim(str .. ' ') == str,
                'trim w/ right spaces'
            )

            assert(
                S.trim(' ' .. str .. ' ') == str,
                'trim w/ left and right spaces'
            )

            assert(
                S.trim(' \r\n\v' .. str .. ' \r\n\v') == str,
                'trim w/ special chars'
            )

            assert(
                S.trim(str, 'yepdhelo ') == 'wor',
                'trim w/ [chars]'
            )

            assert(
                S.trim(str, '') == str,
                'trim w/ empty [chars]'
            )
        end)();

        -- htmlencode
        (function()
            assert(
                S.htmlencode('') == '',
                'htmlencode empty [str]'
            )

            assert(
                S.htmlencode(str) == str,
                'htmlencode w/o special chars'
            )

            assert(
                S.htmlencode([[A<B>'C'&"D"&amp;E</F>]]) == [[A&lt;B&gt;'C'&amp;"D"&amp;amp;E&lt;/F&gt;]],
                'htmlencode w/o quotes'
            )

            local res = [[A&lt;B&gt;&#039;C&#039;&amp;&quot;D&quot;&amp;amp;E&lt;/F&gt;]]
            assert(
                S.htmlencode([[A<B>'C'&"D"&amp;E</F>]], true) == res,
                'htmlencode w/ quotes'
            )
        end)();

        -- starts
        (function()
            assert(
                S.starts(str, 'hello'),
                'starts'
            )

            assert(
                not S.starts(str, 'HELLO'),
                'starts case sensitivity'
            )

            assert(
                S.starts(str, ''),
                'starts w/ empty [prefix]'
            )

            assert(
                not S.starts(str, 'world'),
                'starts [prefix] inside [str]'
            )

            assert(
                not S.starts(str, 'helloworld'),
                'starts over-prefix'
            )

            assert(
                S.starts(str .. ' fooBar', str),
                'starts over-str'
            )

            assert(
                not S.starts(str, str .. ' over-tail'),
                'starts over-tail'
            )
        end)();

        -- ends
        (function()
            assert(
                S.ends(str, 'yep'),
                'ends'
            )

            assert(
                not S.ends(str, 'YEP'),
                'ends case sensitivity'
            )

            assert(
                S.ends(str, ''),
                'ends w/ empty [suffix]'
            )

            assert(
                not S.ends(str, 'world'),
                'ends [suffix] inside [str]'
            )

            assert(
                not S.ends(str, 'worldyep'),
                'ends over-suffix'
            )

            assert(
                S.ends('fooBar ' .. str, str),
                'ends over-str'
            )

            assert(
                not S.ends(str, 'over-head ' .. str),
                'ends over-head'
            )
        end)();

        -- parse_header_value
        (function()
            local _headers = {
                'simple-scalar-string',
                'string;key=value1;key2=value2',
                'string;key=value1;key=value2',
                'na/me; key=value; '
                        .. '__utmz=1.111.11.11.utmcsr=foo|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided); '
                        .. 'tz=Europe%2FMoscow; user_session=d1K_fuBk11; filename="file.txt"',
            }

            local headers = {}

            for idx, line in ipairs(_headers) do
                local parsed = S.parse_header_value(line)
                assert(
                    type(parsed) == 'table',
                    'parse_header_value'
                )
                headers[idx] = parsed
            end

            assert(
                headers[1][''] == _headers[1],
                'parse_header_value scalar'
            )

            assert(
                headers[2][''] == 'string'
                    and headers[2].key
                    and headers[2].key == 'value1'
                    and headers[2].key2
                    and headers[2].key2 == 'value2',
                'parse_header_value table w/ scalar key values'
            )

            assert(
                headers[3][''] == 'string'
                    and type(headers[3].key) == 'table'
                    and tester.tbl_cmpi(headers[3].key, {'value1', 'value2'}),
                'parse_header_value table w/ table key values'
            )

            assert(
                tester.tbl_cmp(headers[4], {
                    ['']         = 'na/me',
                    key          = 'value',
                    __utmz       = '1.111.11.11.utmcsr=foo|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided)',
                    tz           = 'Europe%2FMoscow',
                    user_session = 'd1K_fuBk11',
                    filename     = 'file.txt',
                }),
                'parse_header_value mix'
            )
        end)();

        -- cmpi
        (function()
            assert(
                S.cmpi(str, str),
                'cmpi'
            )

            assert(
                S.cmpi(str, str:upper()),
                'cmpi w/ upper self'
            )

            assert(
                S.cmpi(str, str:lower()),
                'cmpi w/ lower self'
            )

            assert(
                not S.cmpi(str, ''),
                'cmpi empty [str2]'
            )

            assert(
                not S.cmpi('', str),
                'cmpi empty [str1]'
            )

            assert(
                not S.cmpi(str, 'chpachryamba'),
                'cmpi diffs'
            )
        end)();

        -- format
        (function()
            local _str = 'hello %s'
            assert(
                S.format(_str) == 'hello nil',
                'format w/o [vars]'
            )

            assert(
                S.format(_str, 'world') == 'hello world',
                'format w/ scalar [vars]'
            )

            assert(
                S.format(_str, {'world'}) == 'hello world',
                'format w/ table [vars]'
            )
        end)();

        -- apply_patch
        (function()
            S.apply_patch()

            local _str = 'foo'

            assert(
                string.starts and _str.trim,
                'apply_patch mapping'
            )

            assert(
                ('hello %s' % 'world') == 'hello world',
                'apply_patch % scalar'
            )

            assert(
                ('%s %s' % {'hello', 'world'}) == 'hello world',
                'apply_patch % table'
            )
        end)();
    end
end
