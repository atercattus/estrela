local PP = require('estrela.io.pprint')
local PP, SP = PP.print, PP.sprint

print, io.write = ngx.say, ngx.print -- для ленивых :)

local app = require('estrela.web').App {
    ['$'] = function(app, req, resp)
        resp:write(req.method, ' ', req.path, ' ', SP(req.GET, {compact=true}))
    end,

    [''] = {
        GET = function(app, req, resp)
            PP(app)
            print(req.path)
            print(app.route.path)
        end,

        POST = function(app)
            PP(app.req.POST)
            PP(app.req.FILES)
        end,

        [{'HEAD', 'OPTIONS'}] = function()
            ngx.status = 403
            print 'Go home!'
            return ngx.exit(0)
        end,
    },

    ['/fail'] = function()
        foobarSpam()
    end,

    --[[
    [404] = function(app)
        --print 'Route is not found'
        --app:sendInternalErrorPage(404, true)
    end,
    ]]

    --[[
    [500] = function(app, req)
        --print('Ooops in ', req.url, '\n', SP(app.error))
        --self:sendInternalErrorPage(500, true)
    end,
    ]]
}

-- nginx.conf "location /estrela {"
-- Если не указать, то пути маршрутизации должны быть полными: [/estrela/$], ['/estrela/admin/:action/do'] и т.п.
app.router:setPathPrefix('/estrela')

-- для вывода подробного описания ошибок (если не объявлен 500 роут)
app.debug = true

app.filter.before_req:add(function(app)
    app.resp.headers.content_type = 'text/plain'
end)

return app
