--
-- Generated from compile.lt
--


local read = require("lua.read")
local warn = require("lua.warn")
local lex = require("lua.lex")
local scope = require("lua.scope")
local parse = require("lua.parse")
local check = require("lua.check")
local transform = require("lua.transform")
local generate = require("lua.generate")
local compile = function(reader, options, color)
    local lexer = lex(reader, warn.add)
    local tree = parse(lexer, warn.add)
    tree = transform(tree)
    local sc = scope(options.declares, warn.add)
    check(sc, tree, warn.add)
    for _, w in ipairs(warn.warnings) do
        if w.severity >= 10 then
            return nil, warn.format(color)
        end
    end
    return generate(tree), warn.format(color)
end
return {string = function(src, options, color)
    return compile(read.string(src), options or {}, color)
end, file = function(filename, options, color)
    return compile(read.file(filename), options or {}, color)
end}
