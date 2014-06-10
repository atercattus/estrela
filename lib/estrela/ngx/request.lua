local OOP = require('estrela.oop.single')

-- https://docs.djangoproject.com/en/dev/ref/request-response/
-- http://nginx.org/ru/docs/http/ngx_http_core_module.html#variables

return OOP.name 'ngx.request'.class {
    new = function(self)
        self.url  = ngx.var.request_uri
        self.path = ngx.var.uri

        self.method = ngx.req.get_method()
        self.headers = ngx.req.get_headers()
        self.GET = ngx.req.get_uri_args()

        -- ToDo:
        --self.POST = ngx.req.get_post_args() -- ngx.req.read_body()
        --self.COOKIE = nil
        --self.FILES = nil
    end,

    __index__ = function(self, key)
        return ngx.var[key]
    end,
}
