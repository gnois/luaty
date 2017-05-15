local lex_setup = require("lang.lex")
local parse = require("lang.parse")
local ast = require("lang.ast").New()
local reader = require("lang.reader")
local generator = require("lang.generator")
local lang_error = function(msg)
    if string.sub(msg, 1, 8) == "LT-ERROR" then
        return false, "[Luaty] " .. string.sub(msg, 9)
    else
        error(msg)
    end
end
local compile = function(reader, filename, options)
    local ls = lex_setup(reader, filename)
    local parse_success, tree = pcall(parse, ast, ls)
    if not parse_success then
        return lang_error(tree)
    end
    local success, luacode = pcall(generator, tree, filename)
    if not success then
        return lang_error(luacode)
    end
    return true, luacode
end
local lang_loadstring = function(src, filename, options)
    return compile(reader.string(src), filename or "stdin", options)
end
local lang_loadfile = function(filename, options)
    return compile(reader.file(filename), filename or "stdin", options)
end
return {string = lang_loadstring, file = lang_loadfile}