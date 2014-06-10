local OOP = require('estrela.oop.single')
local S = require('estrela.util.string')

local nameRegexp = ':([_a-zA-Z0-9]+)'

local function _preprocessRoutes(routes)
    local prefixes, numerical = {}, {}

    local function _prefixSimplify(prefix)
        local pref = ngx.re.gsub(prefix, nameRegexp, ' ', 'jo')
        return pref
    end

    local function _prefix2regexp(prefix)
        local re = ngx.re.gsub(prefix, nameRegexp, '(?<$1>[^/]+)', 'jo')
        -- если в регулярке указывается ограничитель по концу строки, то добавляю опциональный /? перед концом
        -- после этого регулярка '/foo$' будет подходить и для '/foo', и для '/foo/'
        re = ngx.re.gsub(re, [[\$$]], [[/?$$]], 'jo')
        return '^'..re
    end

    local function _addPrefix(prefix, cb, name)
        local prefixType = type(prefix)
        if prefixType == 'string' then
            table.insert(prefixes, {
                cb          = cb,
                prefixShort = _prefixSimplify(prefix),
                prefix      = prefix,
                name        = name or nil,
                re          = _prefix2regexp(prefix)
            })
        elseif prefixType == 'number' then
            table.insert(numerical, {
                cb          = cb,
                prefix      = prefix,
                name        = name or nil,
            })
        end
    end

    for prefix, cb in pairs(routes) do
        if type(prefix) == 'table' then
            for name, pref in pairs(prefix) do
                _addPrefix(pref, cb, name)
            end
        else
            _addPrefix(prefix, cb)
        end
    end

    table.sort(prefixes, function(a, b)
        return a.prefixShort > b.prefixShort
    end)

    return prefixes, numerical
end

return OOP.name 'ngx.router'.class {
    new = function(self, routes)
        self.routes = routes
        self.prefixes = nil
        self.numerical = nil
        self.pathPrefix = ''
    end,

    setPathPrefix = function(self, prefix)
        self.pathPrefix = prefix
    end,

    route = function(self, pathFull)
        if not self.prefixes then
            -- без "lua_code_cache on" будет пересоздаваться на каждый запрос
            self.prefixes, self.numerical = _preprocessRoutes(self.routes)
        end

        local path = pathFull
        if self.pathPrefix then
            path = path:sub(self.pathPrefix:len() + 1)
        end

        return coroutine.wrap(function()
            for _,p in pairs(self.prefixes) do
                local captures = ngx.re.match(path, p.re, 'jo')
                if captures then
                    coroutine.yield {
                        prefix = p.prefix,
                        cb     = p.cb,
                        params = captures,
                        name   = p.name,
                        path   = path,
                        pathFull = pathFull
                    }
                end
            end
        end)
    end,

    getByName = function(self, name)
        local nameType = type(name)
        if nameType == 'string' then
            for _,p in pairs(self.prefixes) do
                if p.name == name then
                    return p
                end
            end
        elseif nameType == 'number' then
            for _,p in pairs(self.numerical) do
                if (p.prefix == name) or (p.name == name) then
                    return p
                end
            end
        end
    end,

    urlFor = function(self, name, params)
        params = params or {}

        local route = self:getByName(name)
        if not route then
            return nil
        end

        local url = ngx.re.gsub(route.prefix, nameRegexp, function(m) return params[m[1]] or '' end, 'jo')
        return self.pathPrefix .. S.rtrim(url, '$')
    end,
}
