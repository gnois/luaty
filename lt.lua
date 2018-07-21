--
-- Generated from lt.lt
--
local term = require("term")
local compiler = require("lt.compile")
local color = term.color
local write = term.write
local usage = function(err)
    local spec = [=[
Usage: 
  luajit lt.lua [-c1|-f1|c|f] [-t] [-d xvar] src.lt [dst]
  where:
    -c1       Transpile src.lt into dst/src.lua without running
    -f1       Same as -c1 but overwrites destination file
    -c        Transpile src.lt and its dependencies into dst/src.lua, dst/*.lua ... without running
    -f        Same as -c but overwrites destination files
    -t        Enable type checking
    -d xvar   Declares `xvar` to silent undeclared identifier warning
  
  dst specifies an output directory and defaults to ./
  If specified, it must not end with .lt

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
local single = false
local paths = {}
local decls = {}
for s, p in term.scan({...}) do
    if s == "c" or s == "c1" or s == "f" or s == "f1" then
        if already then
            usage("Error: use either -c or -f only")
        end
        already = true
        run = false
        if s == "f" or s == "f1" then
            force = true
        end
        if s == "c1" or s == "f1" then
            single = true
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
        if s == "t" then
            typecheck = true
        elseif s ~= "" then
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
    if src then
        if string.sub(src, 2, 2) == ":" then
            src = string.sub(src, 3)
        end
    end
    if dst then
        dst = string.gsub(dst, term.slash .. "*$", "")
        if string.sub(dst, -string.len(".lt")) == ".lt" then
            usage("Error: output directory `" .. dst .. "` cannot end with .lt")
        end
    end
end
local compile = compiler({declares = decls, typecheck = typecheck, single = single}, color)
if src then
    local _, code, warns, imports = compile.file(src)
    if run then
        if warns then
            write(warns)
        end
        if code then
            local fn = assert(loadstring(code))
            fn()
        else
            write(" Fail to run " .. src)
        end
        write("\n")
    else
        local created = {}
        local existed = {}
        local skips = {}
        for __, file in pairs(imports) do
            write(file.path .. "\n")
            if file.warns then
                write(file.warns)
                write("\n")
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
        write(color.red .. table.concat(fails, "\n") .. color.reset)
    end
else
    local show_results = function(...)
        if select("#", ...) > 1 then
            write(select(2, ...))
        end
    end
    local flush = function()
        io.stdout:flush()
    end
    local read = function()
        return io.stdin:read()
    end
    write("Luaty  \n-- empty line to transpile --\n")
    local list = {}
    repeat
        write("> ")
        flush()
        local s = read()
        if s == "exit" or s == "quit" then
            break
        elseif s and #s > 0 then
            list[#list + 1] = s
        else
            local str = table.concat(list, "\n")
            list = {}
            local _, code, warns = compile.string(str)
            if warns then
                write(warns)
            end
            if code then
                write(color.cyan .. code .. color.reset)
                local fn, err = loadstring(code)
                if err then
                    fn = load("return (" .. fn .. ")", "stdin")
                end
                if fn then
                    show_results(pcall(fn))
                else
                    write(err)
                end
            end
            write("\n")
        end
    until false
end
