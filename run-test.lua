local term = require("term")
local compile = require("lt.compile")

local slash = term.slash
local color = term.color

local switches, paths = term.scan({...})
if switches['h'] then 
    term.usage(
[[
luajit test.lua [-c] path
where:
     path       The path of a directory
     -c         Compile to lua code only
     -h         Show help
]])
end

local run = not switches['c']
local folder = paths[1]

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
        local ok, result = compile.file(filename)
        if not ok then
            term.show_error(result)
            failed()
        end
        if run then
            local fn = assert(loadstring(result))
            fn()
        else
            print(result)
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
        if compile.file(filename) then
            failed()
        end
    end
end

print(color.green .. '[ TEST PASSED ]' .. color.reset)