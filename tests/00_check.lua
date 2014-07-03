--[[ Проверка работоспособности nginx и lua_nginx в целом
]]
if ngx then
    return function()
        return ngx.print(ngx.var.arg_check)
    end
else
    return function(tester)
        math.randomseed(os.time())
        local check = tostring(os.time()) .. tostring(math.random())
        local body, status, headers = tester.req(tester.url, {check=check})
        return tester.check(body, check)
    end
end
