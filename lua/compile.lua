--
-- Generated from compile.lt
--

local read = require("lua.read")
local lex = require("lua.lex")
local parse = require("lua.parse")
local generate = require("lua.generate")
local compile = function(reader, options)
    local lexer = lex(reader)
    local tree = parse(lexer)
    local out = true
    for _, w in ipairs(lexer.warnings) do
        if w.s >= 10 then
            out = nil
        end
    end
    if out then
        out = generate(tree)
    end
    return out, lexer.warnings
end
return {string = function(src, filename, options)
    return compile(read.string(src), filename or "stdin", options)
end, file = function(filename, options)
    return compile(read.file(filename), filename or "stdin", options)
end}