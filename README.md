estrela
=======

Lua framework for nginx or cli (in early stage of development)

### In a nutshell

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

        print(cnt)

        return app:forward('/boo')
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

    ['/external'] = 'ourcoolsite.routes', -- performs require('ourcoolsite.routes')

    ['/fail$'] = function()
        -- this function is not defined => throw a HTTP error #500
        -- error will be handled in route 500 below
        fooBar()
    end,

    [404] = function(app)
        print 'Route is not found'
        --return app:defaultErrorPage()
    end,

    [500] = function(app, req)
        print('Ooops in ', req.url, '\n', SP(app.error))
        --return true
    end,
}

app.router:mount('/admin', {
    ['/:action/do$'] = function(app)
        if not user_function_for_check_auth() then
            return app:abort(404, 'Use cookie, Luke!')
        end
        print('admin do ', app.route.params.action, '<br/>')
    end,
})

app.trigger.before_req:add(function(app, req, resp)
    resp.headers.content_type = 'text/plain'

    if req.GET._method then
        req.method = req.GET._method:upper()
    end
end)

app.trigger.after_req:add(function()
    print 'Goodbye!'
end)
```

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

**config.lua**
```lua
local dev = true

return {
    -- true for verbose error pages
    debug = dev,

    session = {
        storage = {
            handler = 'estrela.cache.engine.shmem',
            shmem = {
                key = 'session_cache',
            },
        },
        handler = {
            handler = 'estrela.ngx.session.engine.common',
            key_name = 'estrela_sid',
            common = {
            },
            cookie = {
                params = { -- see app.response.COOKIE.empty
                    --ttl = 86400,
                    httponly = true,
                },
            },
        },
    },

    router = {
        -- nginx.conf "location /estrela {"
        pathPrefix = '/estrela',
    },
}
```
