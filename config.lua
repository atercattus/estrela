return function(cfg)
    -- Для вывода подробного описания ошибок (если не объявлен 500 роут)
    cfg.debug = true

    -- Разрешаем использовать сессии. Без этого app.session использовать нельзя
    cfg.session.active = true

    -- nginx.conf "location /estrela {"
    -- Если не указать, то пути маршрутизации должны быть полными: ['/estrela/$'], ['/estrela/do/:action'], etc.
    cfg.router.pathPrefix = '/estrela'

    -- Вместо логирования в nginx error_log (стандартное поведение) пишем в отдельный файл
    cfg.error_logger = require('estrela.log.file'):new('/tmp/estrela.error.log')
end
