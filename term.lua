-- ansi colors
local color = {
    reset     = "\27[0m"
    , red     = "\27[91;1m"
    , green   = "\27[92;1m"
    , yellow  = "\27[93;1m"
    , blue    = "\27[94;1m"
    , magenta = "\27[95;1m"
    , cyan    = "\27[96;1m"
    , white   = "\27[97;1m"
}

-- print usage and exit
function usage(text)
    io.stderr:write(text)
    os.exit(1)
end


-- parses command line. returns 2 tables
--   1. map of found switches 
--   2. array of non switch parameters
function scan(args)
    local switches = {}
    local paths, p = {}, 1

    local k = 1
    while args[k] do
        local a = args[k]
        local switch = string.sub(a, 1, 1)
        if switch == "-" then
            switches[string.sub(a, 2)] = true
        else
            paths[p] = a
            p = p + 1
        end
        k = k + 1
    end
    return switches, paths
end


-- result is a table of lexer.warnings
function show_error(result)
    local warns = {}
    for i, m in ipairs(result) do
        warns[i] = string.format(" (%d,%d)" .. color.cyan ..  "  %s" .. color.reset, m.l, m.c, m.msg)
    end
    io.stderr:write(table.concat(warns, "\n") .. "\n")
end


return {
    -- determine forward or back slash
    slash = package.config:sub(1,1)
    , color = color
    , usage = usage
    , scan = scan
    , show_error = show_error
}