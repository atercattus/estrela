local pairs = pairs
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring
local type = type

local ngx_cookie_time = ngx.cookie_time

local M = {}

local function setCookie(cookie, append)
    if not (cookie.name and cookie.value and #cookie.name > 0) then
        return nil, 'missing name or value'
    end

    if cookie['max-age'] then
        cookie['max_age'], cookie['max-age'] = cookie['max-age'], nil
    end

    if type(cookie.expires) == 'number' then
        cookie.expires = ngx_cookie_time(cookie.expires)
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
                v = '=' .. tostring(v)
            end

            if v then
                k = tostring(attrs[k] or k)
                table_insert(cookie_str, k .. v)
            end
        end
    end

    cookie_str = table_concat(cookie_str, '; ')

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
            table_insert(cookies, cookie_str)
            ngx.header['Set-Cookie'] = cookies
        end
    end
end

-- http://tools.ietf.org/html/rfc6265

function M:new()
    local C = {}

    function C:set(cookie, value, expires, path, domain, secure, httponly, append)
        if type(cookie) ~= 'table' then
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
    end

    function C:empty(map)
        local cookie = {
            name     = '',
            value    = '',
            expires  = nil,
            max_age  = nil,
            domain   = nil,
            path     = nil,
            secure   = nil,
            httponly = nil,

            set = function(me, append)
                return self:set(me, append)
            end,
        }

        if map then
            for k, v in pairs(map) do
                cookie[k] = v
            end
        end

        return cookie
    end

    return C
end

return M
