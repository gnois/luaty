local function usage()
  io.stderr:write[[
Usage: luajit test.lua [-c] path
 where:
     path       The path of a directory
     -c         Compile to lua code only
]]
  os.exit(1)
end

-- determine forward or back slash
local slash = package.config:sub(1,1)

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
    dirname = '.' .. slash .. 'tests'
else  -- remove trailing slash(es)
    dirname = string.gsub(dirname, slash .. "*$", '')
end

local compile = require("lt.compile")

local color = {
	magenta = "\27[95;1m"
	, cyan  = "\27[96;1m"
	, reset = "\27[0m"
}

function show_error(result)
    local warns = {}
    for i, m in ipairs(result) do
        warns[i] = string.format(" (%d,%d)" .. color.cyan ..  "  %s" .. color.reset, m.l, m.c, m.msg)
    end
    io.stderr:write(table.concat(warns, "\n") .. "\n")
end


function check(success, result)
    if success then
        return result
    end
    show_error(result)
    error('Compilation should pass. [ TEST FAILED ]')
end

function failure(success, result)
    if success then
        error('Compilation should fail. [ TEST FAILED ]')
    end
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
print('Scanning ' .. dirname .. ' folder...')

local files = scandir(dirname)
for k, v in pairs(files) do
    if #v > 0 and string.sub(v, -string.len('.lt'))=='.lt' then
        print('\n' .. v .. ':')
        filename = dirname .. slash .. v
        local luacode = check(compile.file(filename))
        if run then
            local fn = assert(loadstring(luacode))
            fn()
        else
            print(luacode)
        end
    end
end



-- begin failing tests
dirname = dirname .. slash .. 'fails'
print('Scanning ' .. dirname .. ' folder...')
files = scandir(dirname)
for k, v in pairs(files) do
    if #v > 0 and string.sub(v, -string.len('.lt'))=='.lt' then
        print('\n' .. v .. ':')
        filename = dirname .. slash .. v
        failure(compile.file(filename))
    end
end

print('[ TEST PASSED ]')