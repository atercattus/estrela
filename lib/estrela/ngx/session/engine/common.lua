JSON = require 'cjson'
JSON.encode_sparse_array(true)

local OOP = require 'estrela.oop.single'
local T = require 'estrela.util.table'

return OOP.class {
    new = function(self, storage)
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
            return error('Session storage is locked '..ngx.now(), 2)
        end

        self:load()
    end,

    _gen_sessid = function(self)
        return ngx.md5(ngx.var.remote_addr..ngx.var.pid..ngx.now()..ngx.var.connection..math.random()):sub(1, 16)
    end,

    _get_storage_key = function(self)
        return self.storage_key_prefix .. self.sessid
    end,

    _storage_lock = function(self)
        local lock_ttl = self.storage_lock_ttl
        local lock_timeout = self.storage_lock_timeout
        local try_until = ngx.now() + lock_timeout
        local locked = false
        while true do
            locked = self.storage:add(self.storage_key_lock, 1, lock_ttl)
            if locked or (try_until < ngx.now()) then
                break
            end
            ngx.sleep(0.01)
        end

        return locked
    end,

    _storage_unlock = function(self)
        return self.storage:delete(self.storage_key_lock)
    end,

    _update_session_cookie = function(self)
        if ngx.headers_sent then
            ngx.log(ngx.ERR, 'Error saving the session cookie: headers already sent')
        else
            local app = ngx.ctx.estrela
            local cookie = T.clone(app.config:get('session.handler.cookie.params', {}))
            cookie.name = self.key_name
            cookie.value = self.sessid
            if cookie.ttl then
                cookie.expires = ngx.time() + cookie.ttl
                cookie.ttl = nil
            end

            app.resp.COOKIE:empty(cookie):set()
        end
    end,

    create = function(self)
        self.data = {}
        local tries = 10
        while tries > 0 do
            self.sessid = self:_gen_sessid()
            local storage_key = self:_get_storage_key()
            if self.storage:add(storage_key, '{}', self.ttl) then
                return true
            end

            tries = tries - 1
        end

        self.data, self.sessid = nil, nil
        return false
    end,

    load = function(self)
        local storage_key = self:_get_storage_key()
        self.data = self.storage:get(storage_key)
        if self.data then
            self.data = JSON.decode(self.data)
        end
        if not self.data then
            self.data = {}
        end
    end,

    save = function(self)
        if not self.sessid then
            return
        end

        local storage_key = self:_get_storage_key()

        local res = self.storage:set(storage_key, JSON.encode(self.data), self.ttl)
        self:_storage_unlock()
        return res
    end,

    delete = function(self)
        local storage_key = self:_get_storage_key()
        local res = self.storage:delete(storage_key)
        self.sessid, self.data = nil, nil
        self:_storage_unlock()
        return res
    end,

    gc = function(self)
        return self.storage:flush_expired(1000)
    end,
}
