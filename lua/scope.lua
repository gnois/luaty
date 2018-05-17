--
-- Generated from scope.lt
--
local reserved = require("lua.reserved")
local Builtin = reserved.Builtin
local unused = {_ = true, __ = true, ___ = true}
return function(decls, warn)
    local vstack, vtop = {}, 0
    local bptr = nil
    local declared = function(name)
        for i = vtop, 1, -1 do
            local v = vstack[i]
            if v.name == name then
                v.used = true
                return v.line, v.type
            end
        end
        if Builtin[name] then
            return -1
        end
        if decls and decls[name] then
            return -1
        end
        return 0
    end
    local new_var = function(name, vtype, line, col)
        assert(type(name) == "string")
        assert(type(line) == "number")
        assert(type(col) == "number")
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
            warn(line, col, 3, msg)
        end
        vtop = vtop + 1
        vstack[vtop] = {name = name, type = vtype, used = false, line = line, col = col}
        return vtop
    end
    local new_break = function(line, col)
        assert(type(line) == "number")
        assert(type(col) == "number")
        local blk = bptr
        while blk.tag ~= "Function" do
            if ({While = true, Repeat = true, ForIn = true, ForNum = true})[blk.tag] then
                return 
            end
            blk = blk.outer
        end
        warn(line, col, 10, "`break` must be inside a loop")
    end
    local new_label = function(name, line, col)
        assert(type(name) == "string")
        assert(type(line) == "number")
        assert(type(col) == "number")
        if not bptr.golas then
            bptr.golas = {}
        end
        local blk = bptr
        while blk do
            if blk.golas then
                for _, gl in ipairs(blk.golas) do
                    if gl.label == name then
                        warn(line, col, 4, "duplicate label ::" .. name .. ":: on line " .. gl.line)
                        break
                    end
                end
            end
            blk = blk.outer
        end
        table.insert(bptr.golas, {label = name, used = false, line = line, col = col, vtop = vtop})
    end
    local new_goto = function(name, line, col)
        assert(type(name) == "string")
        assert(type(line) == "number")
        assert(type(col) == "number")
        if not bptr.golas then
            bptr.golas = {}
        end
        table.insert(bptr.golas, {go = name, match = false, line = line, col = col, vtop = vtop})
    end
    local enter_block = function(tag)
        local newb = {tag = tag, vstart = vtop + 1, outer = bptr, blocks = nil, golas = nil}
        if bptr then
            if not bptr.blocks then
                bptr.blocks = {}
            end
            table.insert(bptr.blocks, newb)
        end
        bptr = newb
    end
    local leave_block = function()
        for n = bptr.vstart, vtop do
            local v = vstack[n]
            if not v.used then
                if not unused[v.name] then
                    warn(v.line, v.col, 3, "unused variable `" .. v.name .. "`")
                end
            end
        end
        local test_goto
        test_goto = function(blocks, lbl)
            if blocks then
                for _, b in ipairs(blocks) do
                    test_goto(b.blocks, lbl)
                    if b.golas then
                        for __, g in ipairs(b.golas) do
                            if lbl.label == g.go then
                                if lbl.vtop >= b.vstart then
                                    warn(g.line, g.col, 9, "goto <" .. g.go .. "> jumps into the scope of variable '" .. vstack[lbl.vtop].name .. "' at line " .. vstack[lbl.vtop].line)
                                end
                                lbl.used = true
                                g.match = true
                            end
                        end
                    end
                end
            end
        end
        local golas = bptr.golas
        if golas then
            for _, g in ipairs(golas) do
                if g.go then
                    for __, lbl in ipairs(golas) do
                        if lbl.label == g.go then
                            if lbl.vtop > g.vtop then
                                warn(g.line, g.col, 9, "goto <" .. g.go .. "> jumps over the variable '" .. vstack[lbl.vtop].name .. "' declared at line " .. vstack[lbl.vtop].line)
                            end
                            lbl.used = true
                            g.match = true
                        end
                    end
                end
            end
            for _, gl in ipairs(golas) do
                if gl.label then
                    test_goto(bptr.blocks, gl)
                end
            end
            for _, gl in ipairs(golas) do
                if gl.label and not gl.used then
                    warn(gl.line, gl.col, 3, "unused label ::" .. gl.label .. "::")
                end
            end
        end
        vtop = bptr.vstart - 1
        assert(vtop >= 0)
        bptr = bptr.outer
    end
    local varargs = function()
        assert(bptr)
        assert(bptr.tag == "Function")
        bptr.varargs = true
    end
    local is_varargs = function()
        local blk = bptr
        while blk.tag ~= "Function" do
            blk = blk.outer
        end
        return blk.varargs
    end
    local begin_func = function()
        enter_block("Function")
    end
    local end_func = function()
        local this = bptr
        leave_block()
        local unused_goto
        unused_goto = function(block)
            if block.golas then
                for __, gl in ipairs(block.golas) do
                    if gl.go and not gl.match then
                        warn(gl.line, gl.col, 12, "no visible label for goto <" .. gl.go .. ">")
                    end
                end
            end
            if block.blocks then
                for _, b in ipairs(block.blocks) do
                    unused_goto(b)
                end
            end
        end
        unused_goto(this)
    end
    return {
        begin_func = begin_func
        , end_func = end_func
        , enter_block = enter_block
        , leave_block = leave_block
        , varargs = varargs
        , is_varargs = is_varargs
        , declared = declared
        , new_var = new_var
        , new_goto = new_goto
        , new_label = new_label
        , new_break = new_break
    }
end
