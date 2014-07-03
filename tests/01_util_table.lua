if ngx then
    return function(tester)
        local T = require('estrela.util.table');

        -- push
        (function()
            local tbl = {}
            T.push(tbl, 42)
            assert(
                tester.tbl_cmpi(
                    tbl,
                    {42}
                ),
                'push single'
            )

            T.push(tbl, 1, 2, 3)
            assert(
                tester.tbl_cmpi(
                    tbl,
                    {42, 1, 2, 3}
                ),
                'push multiple'
            )

            T.push(tbl, {4, {5}, 6})
            assert(
                tester.tbl_cmpi(
                    tbl,
                    {42, 1, 2, 3, {4, {5}, 6}}
                ),
                'push table'
            )
        end)();

        -- clone
        (function()
            assert(
                T.clone(42) == 42,
                'clone non table'
            )

            local tbl = {}
            assert(
                tester.tbl_cmp(
                    T.clone(tbl),
                    tbl
                ),
                'clone empty table'
            )

            local tbl = {1, 2, setmetatable({3}, {1, 2, 3})}
            assert(
                tester.tbl_cmpi(
                    T.clone(tbl),
                    tbl
                ),
                'clone table with metatable'
            )
        end)();

        -- rep
        (function()
            local tbl = {}
            assert(
                tester.tbl_cmpi(
                    T.rep(tbl, 3),
                    {tbl, tbl, tbl}
                ),
                'rep empty table'
            )

            local tbl = {42, {7}}
            assert(
                tester.tbl_cmpi(
                    T.rep(tbl, 5),
                    {tbl, tbl, tbl, tbl, tbl}
                ),
                'rep table'
            )

            assert(
                tester.tbl_cmpi(
                    T.rep({}, 0),
                    {}
                ),
                'rep zero times'
            )
        end)();

        -- join
        (function()
            assert(
                T.join({}) == '',
                'join empty table w/o sep'
            )

            assert(
                T.join({}, '|') == '',
                'join empty table w/ sep'
            )

            assert(
                T.join({1, 2, 3}) == '123',
                'join w/o sep'
            )

            assert(
                T.join({1, 2, 3}, '|') == '1|2|3',
                'join w/ sep'
            )

            assert(
                T.join({1, 2, '4'}, '|') == '1|2|4',
                'join mix item types'
            )
        end)();

        -- len
        (function()
            assert(
                T.len({}) == 0,
                'len empty table'
            )

            assert(
                T.len({1, 2, 42, 100500}) == 4,
                'len table'
            )

            assert(
                T.len({1, 2, nil, 3}) == 3,
                'len table w/ nil item'
            )

            assert(
                T.len({[0]=1, [7]=2, [42]=100500}) == 3,
                'len separate table'
            )
        end)();

        -- list
        (function()
            local tbl = {1, 2, 17}
            local iter = coroutine.wrap(function()
                for _, v in ipairs(tbl) do
                    coroutine.yield(v)
                end
            end)

            assert(
                tester.tbl_cmpi(
                    T.list(iter),
                    tbl
                ),
                'list'
            )
        end)();

        -- range
        (function()
            assert(
                tester.tbl_cmpi(
                    T.list(T.range(1, 5)),
                    {1, 2, 3, 4, 5}
                ),
                'range from..to'
            )

            assert(
                tester.tbl_cmpi(
                    T.range(1, 5):list(),
                    {1, 2, 3, 4, 5}
                ),
                'range from..to to list'
            )

            assert(
                tester.tbl_cmpi(
                    T.range(5):list(),
                    {1, 2, 3, 4, 5}
                ),
                'range to'
            )

            assert(
                tester.tbl_cmpi(
                    T.range(1, 10, 2):list(),
                    {1, 3, 5, 7, 9}
                ),
                'range w/ step'
            )

            assert(
                tester.tbl_cmpi(
                    T.range(5, 1, -2):list(),
                    {5, 3, 1}
                ),
                'range w/ neg step'
            )

            assert(
                tester.tbl_cmpi(
                    T.range(5, 1):list(),
                    {5, 4, 3, 2, 1}
                ),
                'range to..from'
            )

            local idx, res = 0, 0
            for v in T.range(2, 10, 3) do
                idx = idx + 1
                res = res + idx * v
            end
            assert(
                res == (1*2 + 2*5 + 3*8),
                'range for in'
            )

            assert(
                T.range(1, math.huge),
                'range huge'
            )

        end)();

        -- contains
        (function()
            local tbl = {1, 2, 3, {4, 5}}
            assert(
                T.contains(
                    tbl,
                    3
                ),
                'contains exists'
            )

            assert(
                not T.contains(
                    tbl,
                    7
                ),
                'contains non exists'
            )

            assert(
                not T.contains(
                    tbl,
                    nil
                ),
                'contains nil'
            )

            assert(
                not T.contains(
                    tbl,
                    {4, 5}
                ),
                'contains table'
            )

            local sub_tbl = {4, 5}
            local tbl = {1, 2, 3, sub_tbl}

            assert(
                T.contains(
                    tbl,
                    sub_tbl
                ),
                'contains table by ref'
            )

        end)();

        -- __call
        (function()
            assert(
                tester.tbl_cmpi(
                    T(1, 2, 3),
                    {1, 2, 3},
                    true
                ),
                '__call'
            )
        end)();

        -- __add
        (function()
            assert(
                tester.tbl_cmpi(
                    T(1, 2, 3) + 4,
                    {1, 2, 3, 4},
                    true
                ),
                '__add'
            )
        end)();

        -- __mul
        (function()
            assert(
                tester.tbl_cmpi(
                    T(1, 2) * 3,
                    {{1, 2}, {1, 2}, {1, 2}},
                    true
                ),
                '__mul'
            )
        end)();
    end
end
