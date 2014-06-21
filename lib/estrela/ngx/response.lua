local OOP = require('estrela.oop.single')

local function setCookie(cookie, append)
    if not (cookie.name and cookie.value and #cookie.name > 0) then
        return nil, 'missing name or value'
    end

    if cookie['max-age'] then
        cookie['max_age'], cookie['max-age'] = cookie['max-age'], nil
    end

    if type(cookie.expires) == 'number' then
        cookie.expires = ngx.cookie_time(cookie.expires)
    end

    local cookie_str = {cookie.name .. '=' .. cookie.value}
    cookie.name, cookie.value = nil, nil

    local attrs = {
        max_age  = 'max-age',
    }
    for k, v in pairs(cookie) do
        if v and type(v) ~= 'function' then
            if type(v) == 'boolean' then
                v = v and '' or nil
            else
                v = '='..tostring(v)
            end

            if v then
                k = tostring(attrs[k] or k)
                table.insert(cookie_str, k..v)
            end
        end
    end

    cookie_str = table.concat(cookie_str, '; ')

    if not append then
        ngx.header['Set-Cookie'] = nil
    end

    if not ngx.header['Set-Cookie'] then
        ngx.header['Set-Cookie'] = {cookie_str}
    else
        if type(ngx.header['Set-Cookie']) == 'string' then
            ngx.header['Set-Cookie'] = {cookie_str, ngx.header['Set-Cookie']}
        else
            local cookies = ngx.header['Set-Cookie']
            table.insert(cookies, cookie_str)
            ngx.header['Set-Cookie'] = cookies
        end
    end
end

local COOKIE = OOP.name 'ngx.resp_cookie'.class {
    -- http://tools.ietf.org/html/rfc6265

    set = function(self, cookie, value, expires, path, domain, secure, httponly, append)
        if type(cookie)  ~= 'table' then
            cookie = {
                name     = cookie,
                value    = value,
                expires  = expires,
                domain   = domain,
                path     = path,
                secure   = secure,
                httponly = httponly,
            }
        else
            -- если передается таблица, то append идет третьим параметром
            append = value
        end

        return setCookie(cookie, append)
    end,

    empty = function(self, map)
        local COOKIE = self

        local cookie = {
            name     = '',
            value    = '',
            expires  = nil,
            max_age  = nil,
            domain   = nil,
            path     = nil,
            secure   = nil,
            httponly = nil,

            set = function(self, append)
                return COOKIE:set(self, append)
            end,
        }

        if map then
            for k,v in pairs(map) do
                cookie[k] = v
            end
        end

        return cookie
    end,
}

return OOP.name 'ngx.response'.class {
    new = function(self)
        self.headers = ngx.header
        self.COOKIE = COOKIE()
    end,

    finish = function(self)
        return ngx.eof()
    end,

    write = function(self, ...)
        ngx.print(...)
    end,

    writeln = function(self, ...)
        ngx.say(...)
    end,
}
