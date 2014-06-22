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

        self.sessid = app.req.COOKIE[self.key_name]
        if type(self.sessid) == 'table' then
            self.sessid = self.sessid[1]
        end

        if self.sessid then
            self:load()
        else
            self:create()
        end
    end,

    gen_sessid = function(self)
        return ngx.md5(ngx.var.remote_addr..ngx.var.pid..ngx.now()..ngx.var.connection..math.random()):sub(1, 16)
    end,

    get_storage_key = function(self)
        return self.storage_key_prefix .. self.sessid
    end,

    create = function(self)
        self.data = {}
        local tries = 10
        while tries > 0 do
            self.sessid = self:gen_sessid()
            local storage_key = self:get_storage_key()
            if self.storage:add(storage_key, '{}', self.ttl) then
                return true
            end

            tries = tries - 1
        end

        self.data, self.sessid = nil, nil
        return false
    end,

    load = function(self)
        local storage_key = self:get_storage_key()
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

        local storage_key = self:get_storage_key()

        return self.storage:set(storage_key, JSON.encode(self.data), self.ttl)
    end,

    delete = function(self)
        local storage_key = self:get_storage_key()
        local res = self.storage:delete(storage_key)
        self.sessid, self.data = nil, nil
        return res
    end,

    gc = function(self)
        return self.storage:flush_expired(1000)
    end,
}
