--
-- Generated from scope.lt
--

local reserved = require("lua.reserved")
local Builtin = reserved.Builtin
local unused = {_ = true, __ = true, ___ = true}
return function(err)
    local vstack = {}
    local vtop = 1
    local enter_block = function(f, isloop)
        assert(f)
        f.block = {prev = f.block, vstart = vtop, isloop = isloop}
    end
    local leave_block = function(f)
        assert(f)
        local vstart = f.block.vstart
        for n = vstart, vtop - 1 do
            if vstack[n]["goto"] then
                local g = vstack[n]
                for m = n - 1, vstart, -1 do
                    if vstack[m].label == g["goto"] then
                        vstack[m].used = true
                        g.match = true
                        break
                    end
                end
                for m = n + 1, vtop - 1 do
                    if vstack[m].name then
                        err("goto <" .. g.name .. "> jumps into the scope of variable " .. vstack[m].name .. " at line " .. vstack[m].line)
                    end
                    if vstack[m].label == g["goto"] then
                        vstack[m].used = true
                        g.match = true
                        break
                    end
                end
            end
        end
        for n = vstart, vtop - 1 do
            local v = vstack[n]
            if not v.used then
                if v.name and not unused[v.name] then
                    err("unused variable `" .. v.name .. "` declared on line " .. v.line)
                elseif v.label then
                    err("unused label <" .. v.label .. "> on line " .. v.line)
                end
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
    local declared = function(name)
        for i = vtop - 1, 1, -1 do
            local v = vstack[i]
            if v.name == name then
                v.used = true
                return v.line
            end
        end
        if Builtin[name] then
            return -1
        end
        return 0
    end
    local declare = function(name, vtype, line)
        assert(name)
        local ln = declared(name)
        if ln ~= 0 then
            local which = "previous"
            if ln == -1 then
                which = "global"
            end
            local msg = "shadowing " .. which .. " variable `" .. name .. "`"
            if ln > 0 then
                msg = msg .. " declared on line " .. ln
            end
            err(msg)
        end
        vstack[vtop] = {name = name, type = vtype, used = false, line = line}
        vtop = vtop + 1
        return vtop
    end
    local dec_label = function(f, name, line)
        assert(f)
        assert(name)
        local vstart = f.block.vstart
        for n = vstart, vtop - 1 do
            if vstack[n].label == name then
                err("duplicate label <" .. name .. "> in the same scope on line " .. vstack[n].line .. " and " .. line)
                break
            end
        end
        vstack[vtop] = {label = name, used = false, line = line}
        vtop = vtop + 1
        return vtop
    end
    local dec_goto = function(name, line)
        assert(name)
        vstack[vtop] = {["goto"] = name, match = false, line = line}
        vtop = vtop + 1
        return vtop
    end
    return {enter_block = enter_block, leave_block = leave_block, begin_func = begin_func, end_func = end_func, declared = declared, declare = declare, dec_label = dec_label, dec_goto = dec_goto}
end