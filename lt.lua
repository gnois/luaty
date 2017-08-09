local compile = require("lt.compile")

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

local color = {
	magenta = "\27[95;1m"
	, cyan  = "\27[96;1m"
	, reset = "\27[0m"
}
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
local ok, result = compile.file(source)
if ok then
    if run then
        local fn = assert(loadstring(result))
        fn()
    else
        local dest = filenames[2] or string.gsub(filenames[1], "%.lt", '.lua')
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
        f:write(result)
    end
else
    local warns = {}
    for i, m in ipairs(result) do
        warns[i] = string.format(" (%d,%d)" .. color.cyan ..  "  %s" .. color.reset, m.l, m.c, m.msg)
    end
    io.stderr:write(color.magenta .. "Error compiling " .. source .. "\n" .. color.reset)
    io.stderr:write(table.concat(warns, "\n") .. "\n")
end