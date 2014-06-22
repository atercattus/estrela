local app = require('estrela.web').App {
    ['$'] = function(app)
        ngx.say 'Hello world'
    end,
}

app.trigger.before_req:add(function(app)
    app.resp.headers.content_type = 'text/plain'
end)

app.trigger.after_req:add(function()
    ngx.say 'Goodbye!'
end)

return app
