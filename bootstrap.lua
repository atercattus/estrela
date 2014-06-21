local PP = require('estrela.io.pprint')
local PP, SP = PP.print, PP.sprint

print, io.write = ngx.say, ngx.print -- для ленивых :)

local app = require('estrela.web').App {
    ['$'] = function(app)
        print 'Hello world!'
    end,
}

app.trigger.before_req:add(function(app)
    app.resp.headers.content_type = 'text/plain'
end)

app.trigger.after_req:add(function()
    print 'Goodbye!'
end)

return app
