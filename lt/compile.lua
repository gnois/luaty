--
-- Generated from compile.lt
--

local read = require("lt.read")
local ast = require("lt.ast")
local lexer = require("lt.lex")
local parse = require("lt.parse")
local generate = require("lt.generate")
local color = {magenta = "\27[95;1m", cyan = "\27[96;1m", reset = "\27[0m"}
local compile = function(reader, filename, options)
    local lx = lexer(reader, filename)
    local ok, tree = pcall(parse, ast.New(), lx)
    local warns = {}
    if #lx.warnings > 0 then
        for i, m in ipairs(lx.warnings) do
            warns[i] = string.format("%s: (%d,%d)" .. color.cyan .. "  %s" .. color.reset, filename, m.l, m.c, m.msg)
        end
        return false, table.concat(warns, "\n")
    end
    local code = generate(tree)
    return true, code
end
return {string = function(src, filename, options)
    return compile(read.string(src), filename or "stdin", options)
end, file = function(filename, options)
    return compile(read.file(filename), filename or "stdin", options)
end}