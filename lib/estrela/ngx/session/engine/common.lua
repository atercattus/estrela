JSON = require 'cjson'
JSON.encode_sparse_array(true)

local OOP = require 'estrela.oop.single'
local T = require 'estrela.util.table'

return OOP.class {
    -- ToDo: блокировка записи на время использования
    new = function(self, storage)
        self.data = nil
        self.storage = storage
        self.ttl = 86400

        local app = ngx.ctx.estrela
        self.key_name = app.config:get('session.handler.key_name', 'estrela_sid')

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

    create = function(self)
        self.data = {}
        local tries = 10
        while tries > 0 do
            self.sessid = self:gen_sessid()
            if self.storage:add(self.sessid, '{}', self.ttl) then
                return true
            end

            tries = tries - 1
        end

        self.data, self.sessid = nil, nil
        return false
    end,

    load = function(self)
        self.data = self.storage:get(self.sessid)
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

        local app = ngx.ctx.estrela
        local cookie = T.clone(app.config:get('session.handler.cookie.params', {}))
        cookie.name = self.key_name
        cookie.value = self.sessid
        if cookie.ttl then
            cookie.expires = ngx.time() + cookie.ttl
            cookie.ttl = nil
        end

        app.resp.COOKIE:empty(cookie):set()

        return self.storage:set(self.sessid, JSON.encode(self.data), self.ttl)
    end,

    delete = function(self)
        local res = self.storage:delete(self.sessid)
        self.sessid, self.data = nil, nil
        return res
    end,

    gc = function(self)
        return self.storage:flush_expired(1000)
    end,
}
