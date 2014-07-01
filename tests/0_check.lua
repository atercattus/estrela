--[[ Проверка работоспособности nginx и lua_nginx в целом + доступа к estrela
]]
if ngx then
    return function()
        local _ = require('estrela.web').App
        return ngx.print 'ok'
    end
else
    return function(tester)
        local body, status, headers = tester.req(tester.url)
        return tester.check('ok', body)
    end
end
