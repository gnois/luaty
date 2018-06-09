--
-- Generated from compile.lt
--
local read = require("lua.read")
local lex = require("lua.lex")
local scope = require("lua.scope")
local parse = require("lua.parse")
local check = require("lua.check")
local transform = require("lua.transform")
local generate = require("lua.generate")
local compile = function(reader, options, color)
    local warnings = {}
    local warn = function(line, col, severity, msg)
        local w = {line = line, col = col, severity = severity, msg = msg}
        for i, m in ipairs(warnings) do
            if line == m.line and severity < m.severity then
                return 
            end
            if line < m.line or line == m.line and col < m.col then
                table.insert(warnings, i, w)
                return 
            end
        end
        table.insert(warnings, w)
    end
    local warning = function()
        local warns = {}
        for i, m in ipairs(warnings) do
            local clr = color.yellow
            if m.severity > 2 then
                clr = color.red
            elseif m.severity > 1 then
                clr = color.magenta
            end
            warns[i] = string.format(" %d,%d:" .. clr .. "  %s" .. color.reset, m.line, m.col, m.msg)
        end
        if #warns > 0 then
            return table.concat(warns, "\n")
        end
    end
    local continue = function()
        for _, w in ipairs(warnings) do
            if w.severity > 2 then
                return false
            end
        end
        return true
    end
    local lexer = lex(reader, warn)
    if continue() then
        local tree = parse(lexer, warn)
        if continue() then
            tree = transform(tree)
            if continue() then
                local sc = scope(options.declares, warn)
                check(sc, tree, warn)
                if continue() then
                    return generate(tree), warning()
                end
            end
        end
    end
    return nil, warning()
end
return {string = function(src, options, color)
    return compile(read.string(src), options or {}, color)
end, file = function(filename, options, color)
    return compile(read.file(filename), options or {}, color)
end}
