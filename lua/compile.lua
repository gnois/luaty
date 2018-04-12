--
-- Generated from compile.lt
--

local read = require("lua.read")
local lex = require("lua.lex")
local scope = require("lua.scope")
local parse = require("lua.parse")
local transform = require("lua.transform")
local generate = require("lua.generate")
local compile = function(reader, options)
    local lexer = lex(reader)
    local sc = scope(options.declares, function(severe, msg)
        lexer.error(lexer, severe, "%s", msg)
    end)
    local tree = transform(parse(sc, lexer))
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
return {string = function(src, options)
    return compile(read.string(src), options or {})
end, file = function(filename, options)
    return compile(read.file(filename), options or {})
end}