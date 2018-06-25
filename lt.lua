--
-- Generated from lt.lt
--
local term = require("term")
local compiler = require("lt.compile")
local color = term.color
local usage = function(err)
    local spec = [=[
Usage: 
  luajit lt.lua [-f] [-c] src.lt [-d xvar]
  where:
    -c        Transpile src.lt and its dependecies into src.lua, *.lua ... without running
    -f        Transpile src.lt and its dependecies into src.lua, *.lua ... without running, overwriting them if they exist
    -d xvar   Declares `xvar` to silent undeclared identifier warning
    
  Running without parameters enters Read-Generate-Eval-Print loop
]=]
    err = err or ""
    err = err .. "\n" .. spec
    term.usage(err)
end
local run = true
local force = false
local already = false
local paths = {}
local decls = {}
for s, p in term.scan({...}) do
    if s == "c" or s == "f" then
        if already then
            usage("Error: use -c or -f only")
        end
        already = true
        run = false
        if s == "f" then
            force = true
        end
        if p then
            table.insert(paths, p)
        end
    elseif s == "d" then
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
if #paths > 1 then
    usage("Error: only one file accepted")
end
local compile = compiler({declares = decls}, color)
if run and not paths[1] then
    local print_results = function(...)
        if select("#", ...) > 1 then
            print(select(2, ...))
        end
    end
    print("Luaty  \n-- empty line to transpile --")
    local list = {}
    repeat
        if #list > 0 then
            io.stdout:write(">>")
        else
            io.stdout:write("> ")
        end
        io.stdout:flush()
        local s = io.stdin:read()
        if s == "exit" or s == "quit" then
            break
        elseif #s == 0 then
            local str = table.concat(list, "\n")
            list = {}
            local typ, code, warns = compile.string(str)
            if warns then
                print(warns)
            end
            if code then
                print(color.yellow .. code .. color.reset)
                local fn, err = loadstring(code)
                if err then
                    fn = load("return (" .. fn .. ")", "stdin")
                end
                if fn then
                    io.stdout:write("=>")
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
    local typ, code, warns, imports = compile.file(paths[1])
    if run then
        if warns then
            print(warns)
        end
        if code then
            local fn = assert(loadstring(code))
            fn()
        else
            print(" Fail to run " .. paths[1])
        end
    else
        local skips = {}
        for key, file in pairs(imports) do
            print(file.path)
            local dest = string.gsub(file.path, "%.lt", ".lua")
            while dest == paths[1] do
                dest = dest .. ".lua"
            end
            if file.warns then
                print(file.warns)
            end
            if file.code then
                if not force then
                    local f = io.open(dest, "r")
                    if f then
                        skips[dest] = 1
                        f:close()
                    end
                end
                if not skips[dest] then
                    local f, err = io.open(dest, "wb")
                    if not f then
                        error(err)
                    end
                    local basename = string.gsub(file.path, "(.*[/\\])(.*)", "%2")
                    f:write("--\n-- Generated from " .. basename .. "\n--")
                    f:write(file.code)
                    f:close()
                end
            else
                skips[dest] = -1
            end
        end
        local fails, f = {}, 1
        for k, v in pairs(skips) do
            if v == 1 then
                fails[f] = k .. " already exists. Use -f to overwrite"
            else
                fails[f] = "Fail to generate " .. k
            end
            f = f + 1
        end
        print(color.red .. table.concat(fails, "\n") .. color.reset)
    end
else
    usage("Error: no file given")
end
