local function usage()
  io.stderr:write[[
Usage: luajit test.lua [-c] path

  Where 
  fullpath   The path of a directory
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
local dirname
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
if not dirname then
    dirname = './tests'
end

local compile = require("lt.compile")

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

print('Scanning ' .. dirname .. ' folder...')
local files = scandir(dirname)
for k, v in pairs(files) do
    if #v > 0 and string.sub(v, -string.len('.lt'))=='.lt' then
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

