xpcall(
    function()
        require('bootstrap'):serve()
    end,
    function(err)
        ngx.say(err)
    end
)
