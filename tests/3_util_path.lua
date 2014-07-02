if ngx then
    return function(tester)
        local P = require('estrela.util.path');

        -- split
        (function()
            local info = P.split('/path/to/file.ext')
            assert(
                    info.path == '/path/to/'
                and info.name == 'file.ext'
                and info.ext  == 'ext',
                'split'
            )

            local info = P.split('/path/to/')
            assert(
                info.path == '/path/to/'
                        and info.name == ''
                        and info.ext  == '',
                'split only path'
            )

            local info = P.split('/path/to')
            assert(
                info.path == '/path/'
                        and info.name == 'to'
                        and info.ext  == '',
                'split w/o ext'
            )

            local info = P.split('/')
            assert(
                info.path == '/'
                        and info.name == ''
                        and info.ext  == '',
                'split root'
            )

            local info = P.split('filename')
            assert(
                info.path == ''
                        and info.name == 'filename'
                        and info.ext  == '',
                'split only filename'
            )
        end)();

        -- rel
        (function()
            assert(
                P.rel('/path/to/estrela', '/path/to/estrela/bootstrap.lua') == 'bootstrap.lua',
                'rel in workdir'
            )

            assert(
                P.rel('/path/to/estrela', '/path/to/estrela/foo/bar/bootstrap.lua') == 'foo/bar/bootstrap.lua',
                'rel downward path'
            )

            assert(
                P.rel('/path/to/estrela', '/path/foo/bar/bootstrap.lua') == '../../foo/bar/bootstrap.lua',
                'rel upward+downward path'
            )

            assert(
                P.rel('/path/to/lua/lib/estrela', '/bootstrap.lua') == '../../../../../bootstrap.lua',
                'rel upward path'
            )

            assert(
                P.rel('/path/to/lua/lib/estrela', '/foo/bar/bootstrap.lua') == '../../../../../foo/bar/bootstrap.lua',
                'rel upward to root+downward path'
            )

            assert(
                P.rel('/', '/path/to/lua/bootstrap.lua') == 'path/to/lua/bootstrap.lua',
                'rel downward from root path'
            )
        end)();

        -- join
        (function()
            assert(
                P.join('/') == '/',
                [[join('/')]]
            )

            assert(
                P.join('/', 'foo', 'bar') == '/foo/bar',
                [[join('/', 'foo', 'bar')]]
            )

            assert(
                P.join('/path', 'to', 'file') == '/path/to/file',
                [[join('/path', 'to', 'file')]]
            )

            assert(
                P.join('/path/', 'to', 'file') == '/path/to/file',
                [[join('/path/', 'to', 'file')]]
            )

            assert(
                P.join('/path/', 'to/', 'file/') == '/path/to/file',
                [[join('/path/', 'to/', 'file/')]]
            )
        end)();
    end
end
