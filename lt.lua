local term = require("term")
local compile = require("lt.compile")
local color = term.color

function usage()
    term.usage([[
Usage: 
  luajit lt.lua [-c] [file.lt] [file.lua]
  where:
    -c   Write into file.lua without running
         file.lua is optional
  
  Running without parameters enters Read-Generate-Eval-Print loop
]])
end

local switches, paths = term.scan({...})
-- sanity
for k, _ in pairs(switches) do
    if k ~= 'c' then
        usage()
    end
end
if #paths > 2 then
    usage()
end

local run = not switches['c']
local source = paths[1]

if not source and run then
    -- REPL
    -- https://stackoverflow.com/questions/20410082/why-does-the-lua-repl-require-you-to-prepend-an-equal-sign-in-order-to-get-a-val
    function print_results(...)
        -- This function takes care of nils at the end of results and such
        if select('#', ...) > 1 then
            print(select(2, ...))
        end
    end
    print("Luaty")
    print("-- empty line to end block --\n")
    local list = {}
    repeat
        if #list > 0 then
            io.stdout:write('>>')
        else
            io.stdout:write('> ')
        end
        io.stdout:flush()
        local s = io.stdin:read()
        if s == 'exit' then
            break
        elseif #s == 0 then
            local str = table.concat(list, '\n')
            list = {}
            local ok, code = compile.string(str)
            if ok then
                print(color.yellow .. code .. color.reset)
                local fn, err = loadstring(code)
                if err then -- Maybe it's an expression
                    -- This is a bad hack, but it might work well enough
                    fn = load('return (' .. fn .. ')', 'stdin')
                end

                if fn then
                    io.stdout:write('=>')
                    print_results(pcall(fn))
                else
                    print(err)
                end
            else
                term.show_error(code)
            end
        else
            list[#list + 1] = s
        end
    until false

else
    local ok, code = compile.file(source)
    if ok then
        if run then
            local fn = assert(loadstring(code))
            fn()
        else
            local dest = paths[2] or string.gsub(paths[1], "%.lt", '.lua')
            while dest == source do
                dest = dest .. '.lua'
            end
            --print("Compiled " .. source .. " to " .. dest)
            local f, err = io.open(dest, 'wb')
            if not f then
                error(err)
            end
            
            -- get the filename without path
            local basename = string.gsub(source, "(.*[/\\])(.*)", "%2")
            f:write("--\n-- Generated from " .. basename .. "\n--\n\n")
            f:write(code)
        end
    else
        io.stderr:write(color.magenta, "Error compiling " .. source .. "\n", color.reset)
        term.show_error(code)
    end
end