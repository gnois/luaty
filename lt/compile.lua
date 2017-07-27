--
-- Generated from compile.lt
--

local read = require("lt.read")
local lexer = require("lt.lex")
local parse = require("lt.parse")
local ast = require("lt.ast")
local generate = require("lt.generate")
local color = {magenta = "\27[95;1m", cyan = "\27[96;1m", reset = "\27[0m"}
local compile = function(reader, filename, options)
    local ls = lexer(reader, filename)
    local ok, tree, code
    ok, tree = pcall(parse, ast.New(), ls)
    local warns = {}
    if #ls.warnings > 0 then
        for i, m in ipairs(ls.warnings) do
            warns[i] = string.format("%s: (%d,%d)" .. color.cyan .. "  %s" .. color.reset, filename, m.l, m.c, m.msg)
        end
        return false, table.concat(warns, "\n")
    end
    code = generate(tree)
    return true, code
end
return {string = function(src, filename, options)
    return compile(read.string(src), filename or "stdin", options)
end, file = function(filename, options)
    return compile(read.file(filename), filename or "stdin", options)
end}