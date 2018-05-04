--
-- Generated from warn.lt
--


local warnings = {}
local add = function(line, col, severity, msg)
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
local format = function(color)
    local warns = {}
    for i, m in ipairs(warnings) do
        local clr = color.yellow
        if m.severity >= 10 then
            clr = color.red
        end
        warns[i] = string.format(" %d,%d:" .. clr .. "  %s" .. color.reset, m.line, m.col, m.msg)
    end
    if #warns > 0 then
        return table.concat(warns, "\n")
    end
end
return {warnings = warnings, add = add, format = format}
