local dev = true

return {
    -- Для вывода подробного описания ошибок (если не объявлен 500 роут)
    debug = dev,

    router = {
        -- nginx.conf "location /estrela {"
        -- Если не указать, то пути маршрутизации должны быть полными: ['/estrela/$'], ['/estrela/do/:action'], etc.
        pathPrefix = '/estrela',
    },
}
