JSON = require 'cjson'
JSON.encode_sparse_array(true)

xpcall(
    function()
        local app = require('bootstrap')
        app.config:load(require('config'))
        app:serve()
    end,
    function(err)
        ngx.log(ngx.ERR, err)
        ngx.status = 500
        ngx.print 'Ooops! Something went wrong'
        ngx.exit(0)
    end
)
