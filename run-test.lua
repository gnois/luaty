local term = require("term")
local compile = require("lua.compile")

local slash = term.slash
local color = term.color

function usage(err)
    local spec = [[
luajit test.lua [-c] path
where:
     path       The path of a directory
     -c         Compile to lua code only
     -h         Show help
]]
    term.usage(spec)
end

local run = true
local folder

for s, p in term.scan({...}) do
    if s == 'c' then
        run = false
    elseif s == 'h' then
        usage()
    else
        folder = p
    end
end

if not folder then
    folder = '.' .. slash .. 'tests'
else  -- remove trailing slash(es)
    folder = string.gsub(folder, slash .. "*$", '')
end


function failed()
    error(color.red .. '[ TEST FAILED ]' .. color.reset)
end


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


-- begin passing tests
print('Scanning ' .. folder .. ' folder...')

local files = scandir(folder)
for k, v in pairs(files) do
    if #v > 0 and string.sub(v, -string.len('.lt'))=='.lt' then
        print('\n' .. v .. ':')
        filename = folder .. slash .. v
        local code, warn = compile.file(filename, {}, color)
        if not code then
            io.stderr:write(warns .. "\n")
            failed()
        end
        if run then
            local fn = assert(loadstring(code))
            fn()
        else
            print(code)
        end
    end
end



-- begin failing tests
folder = folder .. slash .. 'fails'
print('Scanning ' .. folder .. ' folder...')
files = scandir(folder)
for k, v in pairs(files) do
    if #v > 0 and string.sub(v, -string.len('.lt'))=='.lt' then
        print('\n' .. v .. ':')
        filename = folder .. slash .. v
        local code, warns = compile.file(filename, {}, color)
        if not warns then
            failed()
        end
    end
end

print(color.green .. '[ TEST PASSED ]' .. color.reset)