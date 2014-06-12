local UPLOAD = require('resty.upload')

local OOP = require('estrela.oop.single')
local S = require('estrela.util.string')

local function parsePostBody()
    local POST, FILES = {}, {}

    local body_len = tonumber(ngx.var.content_length) or 0
    local chunk_size = body_len > 102400 and 102400 or 8192

    local form, err = UPLOAD:new(chunk_size)
    if form then
        form:set_timeout(1000)

        local field = {}

        while true do
            local type_, res, err = form:read()
            if not type_ then
                ngx.say("failed to read: ", err)
                break
            end

            if type_ == 'header' then
                local hdr_key, hdr_body = res[1], S.parse_header_value(res[2])
                if S.cmpi(hdr_key, 'Content-Disposition') then
                    field.name = hdr_body.name
                    if hdr_body.filename then
                        field.filename = hdr_body.filename
                        field.size = 0
                    else
                        field.data = {}
                    end
                elseif S.cmpi(hdr_key, 'Content-Type') then
                    field.type = hdr_body['']
                --else -- игнорируем другие заголовки
                end
            elseif type_ == 'body' then
                local res_len = #res
                if res_len > 0 then
                    if field.data then
                        table.insert(field.data, res)
                    else
                        if not field.tmpfile then
                            field.fd = io.tmpfile()
                        end
                        field.fd:write(res)
                        field.size = field.size + res_len
                    end
                end
            end

            if type_ == 'part_end' then
                if field.filename then
                    if field.fd then
                        field.fd:seek('set', 0)
                    end
                    FILES[field.name] = field
                else
                    field.data = table.concat(field.data)
                    POST[field.name] = field
                end
                field = {}
            elseif type_ == 'eof' then
                break
            end
        end
    else
        ngx.req.read_body()
        POST = ngx.req.get_post_args()
    end

    return POST, FILES
end

local REQ_BODY = OOP.name 'ngx.req_body'.class {
    new = function(self)
        self.POST, self.FILES = parsePostBody()
        --ToDo: удалять временные файлы по завершению обработки запроса
    end,

    __index__ = function(self, key)
        return self.POST[key] or self.FILES[key]
    end,
}

return OOP.name 'ngx.request'.class {
    new = function(self)
        self.url  = ngx.var.request_uri
        self.path = ngx.var.uri

        self.method = ngx.req.get_method()
        self.headers = ngx.req.get_headers()
        self.GET = ngx.req.get_uri_args()

        -- ToDo: COOKIE
    end,

    __index__ = function(self, key)
        if key == 'POST' or key == 'FILES' then
            --ToDo: вызывать ngx.req.discard_body(), если тело так и не было запрошено
            self.BODY = REQ_BODY()
            self.POST, self.FILES = self.BODY.POST, self.BODY.FILES
            return self[key]
        end

        return ngx.var[key]
    end,
}
