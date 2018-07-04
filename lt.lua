--
-- Generated from lt.lt
--
local term = require("term")
local compiler = require("lt.compile")
local color = term.color
local usage = function(err)
    local spec = [=[
Usage: 
  luajit lt.lua [-f] [-c] [-t] [-d xvar] src.lt [dst]
  where:
    -c        Transpile src.lt and its dependecies into ./dst/src.lua, ./dst/*.lua ... without running
    -f        Transpile src.lt and its dependecies into ./dst/src.lua, ./dst/*.lua ... without running, overwriting them if they exist
    -t        Enable type checking
    -d xvar   Declares `xvar` to silent undeclared identifier warning
  
  dst specifies an output directory and must not end with .lt
  If it is empty, output files will reside in the same directory as source file.

  Running without parameters enters Read-Generate-Eval-Print loop
]=]
    err = err or ""
    err = err .. "\n" .. spec
    term.usage(err)
end
local run = true
local force = false
local already = false
local typecheck = false
local paths = {}
local decls = {}
for s, p in term.scan({...}) do
    if s == "c" or s == "f" then
        if already then
            usage("Error: use either -c or -f only")
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
    elseif s == "t" then
        typecheck = true
        if p then
            table.insert(paths, p)
        end
    else
        if s ~= "" then
            usage("Error: unknown switch -" .. s)
        end
        if p then
            table.insert(paths, p)
        end
    end
end
local src, dst
if #paths > 2 then
    usage("Error: only one file with an optional output directory accepted")
else
    src = paths[1]
    dst = paths[2]
    if dst then
        dst = string.gsub(dst, term.slash .. "*$", "")
        if string.sub(dst, -string.len(".lt")) == ".lt" then
            usage("Error: " .. dst .. " as output directory cannot end with .lt")
        end
    end
end
local compile = compiler({declares = decls, typecheck = typecheck}, color)
if src then
    local _, code, warns, imports = compile.file(src)
    if run then
        if warns then
            print(warns)
        end
        if code then
            local fn = assert(loadstring(code))
            fn()
        else
            print(" Fail to run " .. src)
        end
    else
        local created = {}
        local existed = {}
        local skips = {}
        for __, file in pairs(imports) do
            print(file.path)
            if file.warns then
                print(file.warns)
            end
            local dest = string.gsub(file.path, "%.lt", ".lua")
            if dst then
                dest = dst .. term.slash .. dest
            end
            if file.code then
                local name = dest
                local dir
                string.gsub(dest, "(.*[/\\])(.*)", function(d, n)
                    dir = d
                    name = n
                end)
                if not force and not created[dir or ""] then
                    local f = io.open(dest, "r")
                    if f then
                        skips[dest] = 1
                        f:close()
                    end
                end
                if not skips[dest] then
                    if dir and not created[dir] and not existed[dir] then
                        if term.exist_dir(dir) then
                            existed[dir] = true
                        else
                            local x, err = term.mkdir(dir)
                            if not x then
                                error(err)
                            end
                            created[dir] = true
                        end
                    end
                    local f, err = io.open(dest, "wb")
                    if not f then
                        error(err)
                    end
                    local srcname = string.gsub(file.path, "(.*[/\\])(.*)", "%2")
                    f:write("--\n-- Generated from " .. srcname .. "\n--")
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
            local _, code, warns = compile.string(str)
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
end
