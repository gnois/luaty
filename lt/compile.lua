--
-- Generated from compile.lt
--

local lexer = require("lt.lex")
local parse = require("lt.parse")
local ast = require("lt.ast").New()
local read = require("lt.read")
local generate = require("lt.generate")
local lang_error = function(msg)
    if string.sub(msg, 1, 8) == "LT-ERROR" then
        return false, string.sub(msg, 9)
    else
        error(msg)
    end
end
local compile = function(reader, filename, options)
    local ls = lexer(reader, filename)
    local ok, tree, code
    ok, tree = pcall(parse, ast, ls)
    if not ok then
        return lang_error(tree)
    end
    ok, code = pcall(generate, tree, filename)
    if not ok then
        return lang_error(code)
    end
    return true, code
end
local load_string = function(src, filename, options)
    return compile(read.string(src), filename or "stdin", options)
end
local load_file = function(filename, options)
    return compile(read.file(filename), filename or "stdin", options)
end
return {string = load_string, file = load_file}