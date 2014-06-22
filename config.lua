local dev = true

return {
    -- Для вывода подробного описания ошибок (если не объявлен 500 роут)
    debug = dev,

    ob = {
        active = true,
    },

    session = {
        active = true,
        storage = {
            handler = 'estrela.cache.engine.shmem',
            shmem = {
                key = 'session_cache',
            },
        },
        handler = {
            handler = 'estrela.ngx.session.engine.common',
            key_name = 'estrela_sid',
            storage_key_prefix = 'estrela_session:',
            common = {
            },
            cookie = {
                params = { -- смотри app.response.COOKIE.empty
                    --ttl = 86400,
                    httponly = true,
                    path = '/',
                },
            },
        },
    },

    router = {
        -- nginx.conf "location /estrela {"
        -- Если не указать, то пути маршрутизации должны быть полными: ['/estrela/$'], ['/estrela/do/:action'], etc.
        pathPrefix = '/estrela',
    },
}
