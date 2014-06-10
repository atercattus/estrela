package.path = package.path .. ';/data/sites/ater.me/lua/lib/?.lua'

local estrela = require('estrela.web')

-- для ленивых :)
print, io.write = ngx.say, ngx.print

local PP = require('estrela.io.pprint').print
local S = require('estrela.util.string')

-- global var
app = estrela.App {
    ['/$'] = function(app)
        print '<pre>'
        PP(app)
        print '</pre>'
    end,

    [{account = '/:name$', profile = '/profile/:name$'}] = function(app)
        local url = app.router:urlFor(app.route.name, app.route.params)
        print('Hello from ', app.req.method, ' ', url, ' with args ', S.htmlencode(app.req.args))
    end,

    ['/admin'] = function()
        print 'admin default path<br/>'
    end,

    ['/admin/:action/do'] = function(app)
        print('admin do ', app.route.params.action, '<br/>')
    end,

    ['/fail'] = function()
        -- рушим скрипт, бросаем 500 и переходим к соответствующему обработчику
        fooBar()
    end,

    [404] = function()
        print 'Route is not found'
    end,

    [500] = function(app)
        print('Ooops: ', app.error, ' on ', app.req.url)
    end,
}

-- nginx.conf "location /estrela {"
-- Если не указать, то пути маршрутизации должны быть полными: [/estrela/$], ['/estrela/admin/:action/do'] и т.п.
app.router:setPathPrefix('/estrela')
