local term = require("term")
local compile = require("lt.compile")
local color = term.color

function usage()
    term.usage([[
Usage: 
  luajit lt.lua [-c] file.lt [file.lua]
  where:
    -c   Write into file.lua without running.
         file.lua is optional
]])
end

local switches, paths = term.scan({...})
if #paths < 1 or #paths > 2 then
    usage()
end
for k, _ in pairs(switches) do
    if k ~= 'c' then
        usage()
    end
end

local run = not switches['c']
local source = paths[1]

local ok, result = compile.file(source)
if ok then
    if run then
        local fn = assert(loadstring(result))
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
        f:write(result)
    end
else
    io.stderr:write(color.magenta .. "Error compiling " .. source .. "\n" .. color.reset)
    term.show_error(result)
end