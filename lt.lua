local function usage()
    io.stderr:write [[
Luaty usage: 
  luajit lt.lua [-c] source.lt 
  where:
    -c   Compile into Lua without running.
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
        filename = args[k]
    end
    k = k + 1
end
filename = 'tests\\string-method.lt'
if not filename then usage() end

local compile = require("lang.compile")

local luacode = check(compile.file(filename))
if run then
    local fn = assert(loadstring(luacode))
    fn()
else
    print(luacode)
end
