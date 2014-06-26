local coroutine_wrap = coroutine.wrap
local coroutine_yield = coroutine.yield
local pairs = pairs
local require = require
local table_insert = table.insert
local table_sort = table.sort
local type = type

local ngx_gsub = ngx.re.gsub
local ngx_match = ngx.re.match

local S = require('estrela.util.string')
local S_rtrim = S.rtrim

local T = require('estrela.util.table')
local T_contains = T.contains

local name_regexp = ':([_a-zA-Z0-9]+)'

local function _preprocessRoutes(routes)
    local routes_urls, routes_codes = {}, {}

    local function _prefixSimplify(prefix)
        local pref = ngx_gsub(prefix, name_regexp, ' ', 'jo')
        return pref
    end

    local function _prefix2regexp(prefix)
        local re = ngx_gsub(prefix, name_regexp, '(?<$1>[^/]+)', 'jo')
        -- если в регулярке указывается ограничитель по концу строки, то добавляю опциональный /? перед концом
        -- после этого регулярка '/foo$' будет подходить и для '/foo', и для '/foo/'
        re = ngx_gsub(re, [[\$$]], [[/?$$]], 'jo')
        return '^'..re
    end

    local function _addPrefix(prefix, cb, name)
        local prefixType = type(prefix)
        if prefixType == 'string' then
            table_insert(routes_urls, {
                cb          = cb,
                prefixShort = _prefixSimplify(prefix),
                prefix      = prefix,
                name        = name or nil,
                re          = _prefix2regexp(prefix)
            })
        elseif prefixType == 'number' then
            table_insert(routes_codes, {
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

    table_sort(routes_urls, function(a, b)
        return a.prefixShort > b.prefixShort
    end)

    return routes_urls, routes_codes
end

local Router = {}

function Router:getFullUrl(url)
    return self.path_prefix .. url
end

function Router:mount(prefix, routes)
    self.routes_urls, self.routes_codes = nil, nil

    for _prefix, cb in pairs(routes) do
        local _prefix_type = type(_prefix)
        if _prefix_type == 'string' then
            self.routes[prefix .. _prefix] = cb
        elseif _prefix_type == 'number' then
            self.routes[_prefix] = cb
        elseif _prefix_type == 'table' then
            local _new_prefix = {}
            for name, _sub_prefix in pairs(_prefix) do
                _new_prefix[name] = prefix .. _sub_prefix
            end
            self.routes[_new_prefix] = cb
        end
    end
end

function Router:route(pathFull)
    local app = ngx.ctx.estrela

    if not self.routes_urls then
        self.routes_urls, self.routes_codes = _preprocessRoutes(self.routes)
    end

    local path = pathFull
    if self.path_prefix then
        path = path:sub(self.path_prefix:len() + 1)
    end

    local method = app.req.method

    local function check_method(route)
        for k, cb in pairs(route) do
            if type(k) == 'table' then
                if T_contains(k, method) then
                    return cb
                end
            elseif method == k:upper() then
                return cb
            end
        end
        return nil
    end

    return coroutine_wrap(function()
        for _, p in ipairs(self.routes_urls) do
            local captures = ngx_match(path, p.re, 'jo')
            if captures then
                local cb = p.cb

                if type(cb) == 'string' then
                    cb = require(cb)
                end

                if type(cb) == 'table' then
                    cb = check_method(cb)
                end

                if cb then
                    coroutine_yield {
                        prefix = p.prefix,
                        cb     = cb,
                        params = captures,
                        name   = p.name,
                        path   = path,
                        pathFull = pathFull,
                    }
                end
            end
        end
    end)
end

function Router:getByName(name)
    if not self.routes_urls then
        self.routes_urls, self.routes_codes = _preprocessRoutes(self.routes)
    end

    local name_type = type(name)
    if name_type == 'string' then
        for _,p in pairs(self.routes_urls) do
            if p.name == name then
                return p
            end
        end
    elseif name_type == 'number' then
        for _,p in pairs(self.routes_codes) do
            if (p.prefix == name) or (p.name == name) then
                return p
            end
        end
    end
end

function Router:urlFor(name, params)
    params = params or {}

    local route = self:getByName(name)
    if not route then
        return nil
    end

    local url = ngx_gsub(route.prefix, name_regexp, function(m) return params[m[1]] or '' end, 'jo')
    return self:getFullUrl(S_rtrim(url, '$'))
end

local M = {}

function M:new(routes)
    local R = {
        routes = routes,
        routes_urls = nil,
        routes_codes = nil,
        path_prefix = '',
    }

    for k, v in pairs(Router) do
        R[k] = v
    end
    
    return R
end

return M
