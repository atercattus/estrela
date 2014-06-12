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
require('bootstrap'):serve()
```

**bootstrap.lua**
```lua
local PP = require('estrela.io.pprint').print

return require('estrela.web').App {
    [''] = function()
        print 'Hello world'
        print 'POST'
        PP(app.req.POST)
        print 'FILES'
        PP(app.req.FILES)
    end,

    ['/admin/:action/do$'] = function(app)
        print('admin do ', app.route.params.action, '<br/>')
    end,

    [{account = '/:name$', profile = '/profile/:name$'}] = function(app)
        local url = app.router:urlFor(app.route.name, app.route.params)
        print('Hello from ', app.req.method, ' ', url)
    end,

    ['/fail$'] = function()
        -- рушим скрипт, вызывая необъявленную функцию
        -- бросается 500 ошибка, которая вызывает переход к соответствующему обработчику
        fooBar()
    end,

    [404] = function()
        print 'Route is not found'
    end,

    [500] = function(app)
        print('Ooops: ', app.error, ' on ', app.req.url)
    end,
}
```
