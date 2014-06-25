local app = require('estrela.web').App {
    ['$'] = function(app)
        local S = app.session:start()

        local cnt = tonumber(S.cnt) or 0
        ngx.say('Hello world ', cnt, ' times')
        S.cnt = cnt + 1

        app.session:stop()
    end,
}

app.trigger.before_req:add(function(app)
    app.resp.headers.content_type = 'text/plain'
    app.log.debug('New request ', app.req.url)
end)

app.trigger.after_req:add(function()
    ngx.say 'Goodbye!'
end)

return app
