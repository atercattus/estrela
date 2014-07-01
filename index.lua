return xpcall(
    function()
        local app = require('bootstrap')

        local configurator = require('config')
        if type(configurator) == 'function' then
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
