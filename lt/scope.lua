--
-- Generated from scope.lt
--

local builtins = {assert = true, collectgarbage = true, coroutine = true, debug = true, dofile = true, error = true, _G = true, getfenv = true, getmetatable = true, io = true, ipairs = true, load = true, loadfile = true, loadstring = true, math = true, next = true, os = true, package = true, pairs = true, pcall = true, print = true, rawequal = true, rawget = true, rawlen = true, rawset = true, select = true, setfenv = true, setmetatable = true, string = true, table = true, tonumber = true, tostring = true, type = true, unpack = true, _VERSION = true, xpcall = true, module = true, require = true, jit = true}
local unused = {_ = true, __ = true, ___ = true}
return function(err)
    local vstack = {}
    local vtop = 1
    local enter_block = function(f, isloop)
        f.block = {prev = f.block, vstart = vtop, isloop = isloop}
    end
    local leave_block = function(f)
        local vstart = f.block.vstart
        for n = vstart, vtop - 1 do
            if not unused[vstack[n].name] and not vstack[n].used then
                err("unused variable `" .. vstack[n].name .. "` declared on line " .. vstack[n].line)
            end
        end
        vtop = vstart
        assert(vtop >= 1)
        f.block = f.block.prev
    end
    local begin_func = function(pf)
        local f = {parent = pf, block = nil}
        enter_block(f, false)
        return f
    end
    local end_func = function(f)
        leave_block(f)
        return f.parent
    end
    local declare = function(name, vtype, line)
        vstack[vtop] = {name = name, type = vtype, used = false, line = line}
        vtop = vtop + 1
        return vtop
    end
    local declare_label = function(name, line)
        vstack[vtop] = {label = name, used = false, line = line}
        vtop = vtop + 1
        return vtop
    end
    local declared = function(name)
        for i = vtop - 1, 1, -1 do
            if vstack[i].name == name then
                vstack[i].used = true
                return 1
            end
        end
        if builtins[name] then
            return -1
        end
        return 0
    end
    return {enter_block = enter_block, leave_block = leave_block, begin_func = begin_func, end_func = end_func, declared = declared, declare = declare, declare_label = declare_label}
end