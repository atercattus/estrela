estrela
=======

Lua framework for nginx (in early stage of development)

### In a nutshell

**bootstrap.lua**
```lua
local PP = require('estrela.io.pprint').print

return require('estrela.web').App {
    ['$'] = function(app, req, resp)
        app:defer(function()
            ngx.say 'Hello from defer!'
        end)

        local S = app.session:start()

        local cnt = tonumber(S.cnt) or 0
        ngx.say('Hello world ', cnt, ' times')
        S.cnt = cnt + 1

        app.session:stop()

        return app:forward('/boo')
    end,

    [{account = '/:name$', profile = '/profile/:name$'}] = function(app)
        local url = app.router:urlFor(app.route.name, app.route.params)
        ngx.say('Hello from ', app.req.method, ' ', url)
    end,

    ['/boo'] = {
        GET = function(app, req)
            ngx.say 'def GET'
            PP(req.GET)
            PP(req.COOKIE)
        end,

        POST = function(app, req)
            ngx.say 'def POST'
            PP(req.POST)
            PP(req.FILES)
        end,

        [{'HEAD', 'OPTIONS'}] = function()
            ngx.status = 403
            ngx.say 'Go home!'
            return ngx.exit(0)
        end,
    },
    
    ['/redirect'] = function()
        return app:redirect('http://ater.me/')
    end,

    ['/external'] = 'ourcoolsite.routes', -- performs require('ourcoolsite.routes')

    ['/fail$'] = function()
        -- this function is not defined => throw a HTTP error #500
        -- error will be handled in route 500 below
        fooBar()
    end,

    [404] = function(app)
        ngx.say 'Route is not found'
        --return app:defaultErrorPage()
    end,

    [500] = function(app, req)
        ngx.say('Ooops in ', req.url, '\n', SP(app.error))
        --return true
    end,
}

app.router:mount('/admin', {
    ['/:action/do$'] = function(app)
        if not user_function_for_check_auth() then
            return app:abort(404, 'Use cookie, Luke!')
        end
        ngx.say('admin do ', app.route.params.action, '<br/>')
    end,
})

app.trigger.before_req:add(function(app, req, resp)
    resp.headers.content_type = 'text/plain'

    app.log.debug('New request ', app.req.url)

    if req.GET._method then
        req.method = req.GET._method:upper()
    end
end)

app.trigger.after_req:add(function()
    ngx.say 'Goodbye!'
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
return xpcall(
    function()
        local app = require('bootstrap')

        local configurator = require('config')
        if configurator and type(configurator) == 'function' then
            configurator(app.config)
        end

        return app:serve()
    end,
    function(err)
        ngx.log(ngx.ERR, err)
        ngx.status = 500
        ngx.print 'Ooops! Something went wrong'
        return ngx.exit(0)
    end
)
```

**config.lua**
```lua
return function(cfg)
    -- Для вывода подробного описания ошибок (если не объявлен 500 роут)
    cfg.debug = true

    -- Разрешаем использовать сессии. Без этого app.session использовать нельзя
    cfg.session.active = true

    -- nginx.conf "location /estrela {"
    -- Если не указать, то пути маршрутизации должны быть полными: ['/estrela/$'], ['/estrela/do/:action'], etc.
    cfg.router.pathPrefix = '/estrela'

    -- Вместо логирования в nginx error_log (стандартное поведение) пишем в отдельный файл
    cfg.error_logger = require('estrela.log.file'):new('/tmp/estrela.error.log')
end
```
