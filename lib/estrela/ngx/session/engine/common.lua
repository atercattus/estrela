local error = error
local math_random = math.random
local math_randomseed = math.randomseed
local type = type

local ngx_log = ngx.log
local ngx_md5 = ngx.md5
local ngx_now = ngx.now
local ngx_sleep = ngx.sleep
local ngx_time = ngx.time

local JSON = require('cjson')
JSON.encode_sparse_array(true)
local JSON_decode = JSON.decode
local JSON_encode = JSON.encode

local T = require('estrela.util.table')
local T_clone = T.clone

local M = {}

function M:new(storage)
    local S = {}

    function S:new()
        math_randomseed(ngx_time())

        self.data = nil
        self.storage = storage
        self.ttl = 86400

        local app = ngx.ctx.estrela
        self.key_name = app.config:get('session.handler.key_name', 'estrela_sid')
        self.storage_key_prefix = app.config:get('session.handler.storage_key_prefix', 'estrela_session:')
        self.storage_lock_ttl = app.config:get('session.handler.storage_lock_ttl', 10)
        self.storage_lock_timeout = app.config:get('session.handler.storage_lock_timeout', 2)

        self.sessid = app.req.COOKIE[self.key_name]
        if type(self.sessid) == 'table' then
            self.sessid = self.sessid[1]
        end

        if not self.sessid then
            self:create()
        end

        if not self.sessid then
            return error('Cannot start session', 2)
        end

        self:_update_session_cookie()

        self.storage_key_lock = self:_get_storage_key() .. ':lock'

        if not self:_storage_lock() then
            return error('Session storage is locked', 2)
        end

        self:load()

        return self
    end

    function S:_gen_sessid()
        return ngx_md5(ngx.var.remote_addr..ngx.var.pid..ngx_now()..ngx.var.connection..math_random()):sub(1, 16)
    end

    function S:_get_storage_key()
        return self.storage_key_prefix .. self.sessid
    end

    function S:_storage_lock()
        local lock_ttl = self.storage_lock_ttl
        local lock_timeout = self.storage_lock_timeout
        local try_until = ngx_now() + lock_timeout
        local locked = false
        while true do
            locked = self.storage:add(self.storage_key_lock, 1, lock_ttl)
            if locked or (try_until < ngx_now()) then
                break
            end
            ngx_sleep(0.01)
        end

        return locked
    end

    function S:_storage_unlock()
        return self.storage:delete(self.storage_key_lock)
    end

    function S:_update_session_cookie()
        if ngx.headers_sent then
            ngx_log(ngx.ERR, 'Error saving the session cookie: headers already sent')
        else
            local app = ngx.ctx.estrela
            local cookie = T_clone(app.config:get('session.handler.cookie.params', {}))
            cookie.name = self.key_name
            cookie.value = self.sessid
            if cookie.ttl then
                cookie.expires = ngx_time() + cookie.ttl
                cookie.ttl = nil
            end

            app.resp.COOKIE:empty(cookie):set()
        end
    end

    function S:create()
        self.data = {}
        local encoded_data = JSON_encode(self.data)
        local tries = 10
        while tries > 0 do
            self.sessid = self:_gen_sessid()
            local storage_key = self:_get_storage_key()
            if self.storage:add(storage_key, encoded_data, self.ttl) then
                return true
            end

            tries = tries - 1
        end

        self.data, self.sessid = nil, nil
        return false
    end

    function S:load()
        local storage_key = self:_get_storage_key()
        self.data = self.storage:get(storage_key)
        if self.data then
            self.data = JSON_decode(self.data)
        end
        if not self.data then
            self.data = {}
        end
    end

    function S:save()
        if not self.sessid then
            return
        end

        local storage_key = self:_get_storage_key()

        local res = self.storage:set(storage_key, JSON_encode(self.data), self.ttl)
        self:_storage_unlock()
        return res
    end

    function S:delete()
        local storage_key = self:_get_storage_key()
        local res = self.storage:delete(storage_key)
        self.sessid, self.data = nil, nil
        self:_storage_unlock()
        return res
    end

    function S:gc()
        return self.storage:flush_expired(1000)
    end

    return S:new()
end

return M
