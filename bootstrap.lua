local PP = require('estrela.io.pprint')
local PP, SP = PP.print, PP.sprint

print, io.write = ngx.say, ngx.print -- для ленивых :)

local app = require('estrela.web').App {
    ['$'] = function(app)
        app:defer(function()
            print 'Hello from defer!'
        end)

        local cnt = tonumber(app.SESSION.data.cnt) or 0
        cnt = cnt + 1
        app.SESSION.data.cnt = cnt

        print(cnt)
    end,

    ['/s'] = {
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

    ['/fail'] = function()
        foobarSpam()
    end,

    --[[
    [404] = function(app)
        --print 'Route is not found'
        --app:sendInternalErrorPage(404, true)
    end,

    [500] = function(app, req)
        --print('Ooops in ', req.url, '\n', SP(app.error))
        --self:sendInternalErrorPage(500, true)
    end,
    ]]
}

app.filter.before_req:add(function(app)
    app.resp.headers.content_type = 'text/plain'
end)

app.filter.after_req:add(function()
    print 'Goodbye!'
end)

return app
