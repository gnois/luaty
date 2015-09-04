local function usage()
    io.stderr:write [[
Luaty usage: 
  luajit lt.lua [-c] source.lt [dest.lua]
  where:
    -c   Write into dest.lua without running. 
         If dest.lua is not provided, default to source.lua
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
local filenames = {}
local k = 1
while args[k] do
    local a = args[k]
    if string.sub(a, 1, 1) == "-" then
        if string.sub(a, 2, 2) == "c" then
            run = false
        else
            usage()
        end
    else
        table.insert(filenames, a)
    end
    k = k + 1
end

if #filenames < 1 or #filenames > 2 then
    usage()
end

local source = filenames[1]
local compile = require("lang.compile")
local luacode = check(compile.file(source))

if run then
    local fn = assert(loadstring(luacode))
    fn()
else
    local dest = filenames[2] or string.gsub(filenames[1], "%.lt", '.lua')
    while dest == source do
        dest = dest .. '.lua'
    end
    --print("Compiled " .. source .. " to " .. dest)
    local f = io.open(dest, 'w')
    f:write(luacode)
end
