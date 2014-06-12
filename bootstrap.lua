local PP = require('estrela.io.pprint').print
local S = require('estrela.util.string')

print, io.write = ngx.say, ngx.print -- для ленивых :)

local app = require('estrela.web').App {
    ['$'] = function(app, req, resp)
        resp.headers.content_type = 'text/plain'
        resp:write(req.method, ' ', req.path, ' ', req.args)
    end,

    [404] = function(app, req, resp)
        resp.headers.content_type = 'text/plain'
        print 'Route is not found'
    end,

    [500] = function(app, req, resp)
        resp.headers.content_type = 'text/plain'
        print('Ooops in ', req.url, '\n', app.error)
    end,
}

-- nginx.conf "location /estrela {"
-- Если не указать, то пути маршрутизации должны быть полными: [/estrela/$], ['/estrela/admin/:action/do'] и т.п.
app.router:setPathPrefix('/estrela')

return app
