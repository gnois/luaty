local function usage()
  io.stderr:write[[
Usage: luajit runall.lua [-c] fullpath

  Where 
  fullpath   The full path of a directory
  -c         Compile to lua code only
]]
  os.exit(1)
end

local function check(success, result)
    if not success then
        io.stderr:write(result .. "\n")
        os.exit(1)
    else
        return result
    end
end

local run = true
local args = {...}
local k = 1
while args[k] do
    local a = args[k]
    if string.sub(args[k], 1, 1) == "-" then
        if string.sub(a, 2, 2) == "c" then
            run = false
        end
    else
        dirname = args[k]
    end
    k = k + 1
end


local compile = require("lang.compile")

function split(str)
    local t = {}
    local function helper(line) 
        table.insert(t, line) 
        return "" 
    end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local dir = popen('dir /b/a:-D "' .. directory .. '"')
    if dir then 
       local files = dir:read("*a")
       t = split(files)
    end
    return t
end

print('Scanning ' .. dirname .. '\n\n')

local files = scandir(dirname)
for k, v in pairs(files) do
    if #v > 0 then
        print('\n' .. v .. ':')
        filename = dirname .. '\\' .. v    
        local luacode = check(compile.file(filename))
        if run then
            local fn = assert(loadstring(luacode))
            fn()
        else
            print(luacode)
        end
    end
end

