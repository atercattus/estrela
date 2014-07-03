--[[ Проверка работоспособности nginx и lua_nginx в целом
]]
if ngx then
    return function()
        return ngx.print 'ok'
    end
else
    return function(tester)
        local body, status, headers = tester.req(tester.url)
        return tester.check('ok', body)
    end
end
