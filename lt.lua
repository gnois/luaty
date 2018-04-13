local term = require("term")
local compile = require("lua.compile")
local color = term.color

function usage(err)
    local spec = [[
Usage: 
  luajit lt.lua [-c] [src.lt] [dst.lua] [-d xvar]
  where:
    -c        Transpile src.lt into dst.lua without running. dst.lua is optional, default to src.lua if omitted
    -d xvar   Declares `xvar` to silent undeclared identifier warning
    
  Running without parameters enters Read-Generate-Eval-Print loop
]]
    err = err or ''
    err = err .. '\n' .. spec
    term.usage(err)
end


local run = true
local paths = {}
local decls = {}

for s, p in term.scan({...}) do
    if s == 'c' then
        run = false
        if p then
            table.insert(paths, p)
        end
    elseif s == 'd' then
        if p then
            decls[p] = true
        else
            usage("Error: -d requires identifier")
        end
    else
        if p then
            table.insert(paths, p)
        elseif s ~= "" then
            usage("Error: unknown switch -" .. s)
        end
    end
end
if #paths > 2 then
    usage("Error: too many files given")
end

if run and not paths[1] then
    -- REPL
    -- https://stackoverflow.com/questions/20410082/why-does-the-lua-repl-require-you-to-prepend-an-equal-sign-in-order-to-get-a-val
    function print_results(...)
        -- This function takes care of nils at the end of results and such
        if select('#', ...) > 1 then
            print(select(2, ...))
        end
    end
    print("Luaty")
    print("-- empty line to transpile --\n")
    local list = {}
    repeat
        if #list > 0 then
            io.stdout:write('>>')
        else
            io.stdout:write('> ')
        end
        io.stdout:flush()
        local s = io.stdin:read()
        if s == 'exit' or s == 'quit' then
            break
        elseif #s == 0 then
            local str = table.concat(list, '\n')
            list = {}
            local code, warns = compile.string(str, {declares = decls}, color)
            if warns then
                io.stderr:write(warns .. "\n")
            end
            if code then
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
            end
        else
            list[#list + 1] = s
        end
    until false

elseif paths[1] then
    local code, warns = compile.file(paths[1], {declares = decls}, color)

    local dest = paths[2] or string.gsub(paths[1], "%.lt", '.lua')
    while dest == paths[1] do
        dest = dest .. '.lua'
    end
    io.stderr:write(" >> " .. dest .. "\n")
    --io.stderr:write(color.magenta, "Error compiling " .. paths[1] .. "\n", color.reset)
    if warns then
        io.stderr:write(warns .. "\n")
    end

    if code then
        if run then
            -- should not have another filename
            if paths[2] then
                usage("Error: cannot run more than one file")
            end
            local fn = assert(loadstring(code))
            fn()
        else
            --print("Compiled " .. paths[1] .. " to " .. dest)
            local f, err = io.open(dest, 'wb')
            if not f then
                error(err)
            end
            
            -- get the filename without path
            local basename = string.gsub(paths[1], "(.*[/\\])(.*)", "%2")
            f:write("--\n-- Generated from " .. basename .. "\n--\n\n")
            f:write(code)
        end
    else
        if run then
            io.stderr:write(" Fail to run " .. paths[1] .. "\n")
        else
            io.stderr:write(" Fail to generate " .. dest .. "\n")
        end
    end
else
    usage("Error: no file given")
end