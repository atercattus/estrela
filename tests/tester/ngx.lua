local M = require('tests.tester.common')

function M.multitest_srv(self, tests)
    local name = ngx.var.arg_name
    assert(name, 'Test name is not specified')

    local test
    for _, t in ipairs(tests) do
        if t.name == name then
            test = t
            break
        end
    end
    assert(test, 'Test with name [' .. tostring(name) .. '] is not found')

    return test.code(self, test)
end

return M
