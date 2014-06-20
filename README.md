estrela
=======

Lua framework for nginx or cli (in early stage of development)

### In a nutshell

**nginx.conf**
```nginx
http {
    lua_package_path '/path/to/lua/?.lua;/path/to/lua/lib/?.lua;;';

    server {
        location / {
            content_by_lua_file /path/to/lua/index.lua;
        }
    }
}
```

**index.lua**
```lua
JSON = require 'cjson' -- lua-cjson is required
JSON.encode_sparse_array(true)

xpcall(
    function()
        local app = require('bootstrap')
        app.config:load(require('config'))
        app:serve()
    end,
    function(err)
        ngx.log(ngx.ERR, err)
        ngx.status = 500
        ngx.print 'Ooops! Something went wrong'
        ngx.exit(0)
    end
)
```

**bootstrap.lua**
```lua
local PP = require('estrela.io.pprint').print

return require('estrela.web').App {
    ['$'] = function(app, req, resp)
        app:defer(function()
            print 'Hello from defer!'
        end)

        local cnt = tonumber(app.SESSION.data.cnt) or 0
        cnt = cnt + 1
        app.SESSION.data.cnt = cnt

        print cnt
    end,

    ['/admin/:action/do$'] = function(app)
        print('admin do ', app.route.params.action, '<br/>')
    end,

    [{account = '/:name$', profile = '/profile/:name$'}] = function(app)
        local url = app.router:urlFor(app.route.name, app.route.params)
        print('Hello from ', app.req.method, ' ', url)
    end,

    ['/boo'] = {
        GET = function(app, req)
            print 'def GET'
            PP(req.GET)
            PP(req.COOKIE)
        end,

        POST = function(app, req)
            print 'def POST'
            PP(req.POST)
            PP(req.FILES)
        end,

        [{'HEAD', 'OPTIONS'}] = function()
            ngx.status = 403
            print 'Go home!'
            return ngx.exit(0)
        end,
    },

    ['/fail$'] = function()
        -- this function is not defined => throw a HTTP error #500
        -- error will be handled in route 500 below
        fooBar()
    end,

    [404] = function(app)
        print 'Route is not found'
        --app:sendInternalErrorPage(404, true)
    end,

    [500] = function(app, req)
        print('Ooops in ', req.url, '\n', SP(app.error))
    end,
}

app.filter.before_req:add(function(app)
    app.resp.headers.content_type = 'text/plain'
end)

app.filter.after_req:add(function()
    print 'Goodbye!'
end)
```
