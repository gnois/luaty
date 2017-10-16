--
-- Generated from scope.lt
--

local builtins = {assert = true, collectgarbage = true, coroutine = true, debug = true, dofile = true, error = true, _G = true, getfenv = true, getmetatable = true, io = true, ipairs = true, load = true, loadfile = true, loadstring = true, math = true, next = true, os = true, package = true, pairs = true, pcall = true, print = true, rawequal = true, rawget = true, rawlen = true, rawset = true, select = true, setfenv = true, setmetatable = true, string = true, table = true, tonumber = true, tostring = true, type = true, unpack = true, _VERSION = true, xpcall = true, module = true, require = true, jit = true}
local vstack = {}
local vtop = 0
local enter_block = function(f, isloop)
    f.block = {prev = f.block, vstart = vtop, isloop = isloop}
end
local leave_block = function(f)
    vtop = f.block.vstart
    assert(vtop >= 0)
    f.block = f.block.prev
end
local begin_func = function(pf)
    local f = {parent = pf}
    enter_block(f, false)
    return f
end
local end_func = function(f)
    leave_block(f)
    return f.parent
end
local declare = function(name, type)
    vtop = vtop + 1
    vstack[vtop] = {name = name, type = type}
    return vtop
end
local declared = function(name)
    if builtins[name] then
        return -1
    end
    for i = vtop, 1, -1 do
        if vstack[i].name == name then
            return 1
        end
    end
    return 0
end
return {enter_block = enter_block, leave_block = leave_block, begin_func = begin_func, end_func = end_func, declare = declare, declared = declared}