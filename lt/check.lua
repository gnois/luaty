--
-- Generated from check.lt
--
local ty = require("lt.type")
local Tag = require("lt.tag")
local solve = require("lt.solve")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
local relational = function(op)
    return op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" or op == "~="
end
local arithmetic = function(op)
    return op == "+" or op == "-" or op == "*" or op == "/" or op == "^"
end
return function(scope, stmts, warn, import, typecheck)
    local Stmt = {}
    local Expr = {}
    local Type = {}
    local solv = solve()
    local id = 0
    local new = function()
        id = id + 1
        return {tag = TType.New, id = id}
    end
    local fail = function(node)
        local msg = (node.tag or "nil") .. " cannot match a statement type"
        if node.line and node.col then
            warn(node.line, node.col, 3, msg)
        else
            error(msg)
        end
    end
    local check = function(x, y, node, msg)
        if typecheck then
            local t, err = solv.unify(x, y)
            if not t then
                warn(node.line, node.col, 1, msg .. err)
            end
            return t
        end
        return x
    end
    local check_op = function(x, y, node, op)
        return check(x, y, node, "operator `" .. op .. "` ")
    end
    local check_field = function(otype, field, node)
        local t
        if check(ty.tbl({}), otype, node, "field `" .. field .. "` ") then
            t = solv.apply(otype)
            local tbl = ty.get_tbl(t)
            if tbl then
                for _, tk in ipairs(tbl) do
                    if tk[2] == field then
                        return tk[1], t
                    end
                end
                local vt = new()
                tbl[#tbl + 1] = {vt, field}
                return vt, t
            end
        end
        return ty.any(), t
    end
    local check_fn = function(ftype, atypes, node)
        if typecheck then
            local fn = solv.apply(ftype)
            if fn.tag == TType.New then
                solv.extend(fn, ty.func(ty.tuple(atypes), ty.tuple_any()))
            elseif fn.tag == TType.Nil or fn.tag == TType.Val then
                warn(node.line, node.col, 1, "trying to call " .. ty.tostr(fn))
            else
                check(fn, ty.func(ty.tuple(atypes), ty.tuple_any()), node, "function ")
                if fn.outs then
                    return fn.outs
                end
            end
        end
        return ty.tuple_any()
    end
    local check_type = function(tnode, loc)
        local rule = Type[tnode.tag]
        if rule then
            rule(tnode, loc)
        end
    end
    local check_types = function(tnodes, loc)
        if tnodes then
            for _, node in ipairs(tnodes) do
                check_type(node, loc)
            end
        end
    end
    local check_stmts = function(nodes)
        for _, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            if rule then
                rule(node)
            else
                fail(node)
            end
        end
    end
    local check_block = function(nodes)
        scope.enter()
        check_stmts(nodes)
        scope.leave()
    end
    local infer_expr = function(node)
        local rule = Expr[node.tag]
        return rule(node)
    end
    local infer_exprs = function(nodes, start)
        local types, t = {}, 0
        local last = #nodes
        local first = start or 1
        for i = first, last, 1 do
            local nt = infer_expr(nodes[i])
            if nt.tag == TType.Tuple then
                if i == last then
                    for __, v in ipairs(nt) do
                        t = t + 1
                        types[t] = v
                    end
                else
                    t = t + 1
                    types[t] = nt[1] or ty["nil"]()
                end
            else
                t = t + 1
                types[t] = nt
            end
        end
        return types
    end
    local declare = function(var, vtype)
        assert(var.tag == TExpr.Id)
        local name = var.name
        if name == "@" then
            name = "self"
        end
        scope.new_var(name, vtype, var.line, var.col)
    end
    local balance_check = function(lefts, rights)
        local r = #rights
        local l = #lefts
        if r > l then
            warn(rights[1].line, rights[1].col, 1, "assigning " .. r .. " values to " .. l .. " variable(s)")
        end
    end
    Type[TType.Func] = function(node, loc)
        check_types(node.ins, loc)
        check_types(node.outs, loc)
    end
    Type[TType.Tbl] = function(node, loc)
        local vtypes = {}
        local keys = {}
        for i, vk in ipairs(node) do
            local key = vk[2]
            if key then
                local dup = 0
                if "string" == type(key) then
                    for n = 1, #keys do
                        if "string" == type(keys[n]) and key == keys[n] then
                            dup = n
                        end
                    end
                else
                    check_type(key, loc)
                    for n = 1, #keys do
                        if keys[n] and ty.same(keys[n], key) then
                            dup = n
                        end
                    end
                end
                if dup > 0 then
                    warn(loc.line, loc.col, 1, "duplicate key types at position " .. i .. " and " .. dup .. " in table type annotation")
                end
            end
            keys[i] = key
            local vt = vk[1]
            check_type(vt, loc)
            if vt and not key then
                for n = 1, #vtypes do
                    if vtypes[n] and ty.same(vtypes[n], vt) then
                        warn(loc.line, loc.col, 1, "similar value types at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
                vtypes[i] = vt
            end
        end
    end
    Expr[TExpr.Nil] = function()
        return ty["nil"]()
    end
    Expr[TExpr.Bool] = function()
        return ty.bool()
    end
    Expr[TExpr.Number] = function()
        return ty.num()
    end
    Expr[TExpr.String] = function()
        return ty.str()
    end
    Expr[TExpr.Vararg] = function(node)
        if not scope.is_varargs() then
            warn(node.line, node.col, 2, "cannot use `...` in a function without variable arguments")
        end
        return ty.any_vars()
    end
    Expr[TExpr.Id] = function(node)
        local line, t
        if node.name then
            local name = node.name
            if name == "@" then
                name = "self"
            end
            line, t = scope.declared(name)
            if line == 0 then
                warn(node.line, node.col, 1, "undeclared identifier `" .. node.name .. "`")
            end
            if not t then
                t = new()
            end
        end
        return t
    end
    Expr[TExpr.Function] = function(node)
        scope.begin_func()
        check_types(node.types, node)
        check_types(node.retypes, node)
        local ptypes = {}
        for i, p in ipairs(node.params) do
            local t = node.types and node.types[i] or new()
            if p.tag == TExpr.Vararg then
                scope.varargs()
                t = ty.varargs(t)
            else
                declare(p, t)
            end
            ptypes[i] = t
        end
        scope.set_returns(node.retypes)
        check_block(node.body)
        local anno = node.types
        if anno then
            for i, p in ipairs(node.params) do
                if anno[i] then
                    check(infer_expr(p), anno[i], p, "parameter " .. (p.tag == TExpr.Vararg and "..." or p.name) .. " ")
                end
            end
        end
        local rtuple = scope.get_returns() or ty.tuple_none()
        scope.end_func()
        return ty.func(ty.tuple(ptypes), rtuple)
    end
    Expr[TExpr.Table] = function(node)
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            local key = vk[2]
            if key then
                for n = 1, #keys do
                    if keys[n] and ty.same(keys[n], key) then
                        warn(key.line, key.col, 2, "duplicate keys at position " .. i .. " and " .. n .. " in table")
                    end
                end
            end
            keys[i] = key
        end
        local tytys = {}
        local vtyped = false
        local vtype
        for _, vk in ipairs(node.valkeys) do
            local vt, kt
            vt = infer_expr(vk[1])
            kt = vk[2] and infer_expr(vk[2])
            if kt then
                if kt.tag == TType.Val and kt.type == "str" then
                    tytys[#tytys + 1] = {vt, vk[2].value}
                else
                    tytys[#tytys + 1] = {vt, kt}
                end
            else
                if not vtyped then
                    vtyped = true
                    vtype = vt
                elseif not ty.same(vtype, vt) then
                    vtype = nil
                end
            end
        end
        if vtype then
            tytys[#tytys + 1] = {vtype, nil}
        end
        local tbl = ty.tbl(tytys)
        return tbl
    end
    Expr[TExpr.Index] = function(node)
        local ot = infer_expr(node.obj)
        local it = infer_expr(node.idx)
        if it.tag == TExpr.String then
            return check_field(ot, it.value, node)
        end
        check(ty.tbl({}), ot, node, "indexer ")
        return ty.any(), ot
    end
    Expr[TExpr.Field] = function(node)
        local ot = infer_expr(node.obj)
        return check_field(ot, node.field, node)
    end
    Expr[TExpr.Call] = function(node)
        local arg1 = node.args[1]
        if arg1 and arg1.tag == TExpr.String and node.func.tag == TExpr.Id and node.func.name == "require" then
            return import(arg1.value) or ty.any()
        end
        local atypes
        local func = node.func
        local ftype, fobj = infer_expr(func)
        if arg1 and arg1.name == "@" and not func.bracketed then
            if func.tag == TExpr.Field or func.tag == TExpr.Index then
                atypes = infer_exprs(node.args, 2)
                table.insert(atypes, 1, fobj)
            end
        end
        if not atypes then
            atypes = infer_exprs(node.args)
        end
        return check_fn(ftype, atypes, node)
    end
    Expr[TExpr.Unary] = function(node)
        local rtype = infer_expr(node.right)
        local op = node.op
        if op == "#" then
            check_op(ty["or"](ty.tbl({}), ty.str()), rtype, node, op)
            return ty.num()
        end
        if op == "-" then
            check_op(ty.num(), rtype, node, op)
            return ty.num()
        end
        return ty.bool()
    end
    Expr[TExpr.Binary] = function(node)
        local ltype = infer_expr(node.left)
        local rtype = infer_expr(node.right)
        local op = node.op
        if op == "and" then
            return rtype
        end
        if arithmetic(op) or relational(op) then
            if op ~= "==" and op ~= "~=" then
                check_op(ltype, rtype, node, op)
            end
            if relational(op) then
                return ty.bool()
            end
        elseif op == ".." then
            local strnum = ty["or"](ty.num(), ty.str())
            check_op(strnum, rtype, node, op)
            check_op(strnum, ltype, node, op)
            return ty.str()
        end
        return ltype
    end
    Expr[TExpr.Union] = function()
        return ty.any()
    end
    Stmt[TStmt.Expr] = function(node)
        local etype
        etype = infer_expr(node.expr)
    end
    Stmt[TStmt.Local] = function(node)
        check_types(node.types, node)
        balance_check(node.vars, node.exprs)
        local rtypes = infer_exprs(node.exprs)
        for i, var in ipairs(node.vars) do
            local ltype = node.types and node.types[i]
            if ltype and rtypes[i] then
                check(ltype, rtypes[i], node, "type annotation ")
            end
            declare(var, solv.extend(new(), ltype or rtypes[i] or ty["nil"]()))
        end
    end
    local assign_field = function(node, otype, field, rtype)
        local tytys = {{rtype, field}}
        local ok = solv.unify(ty.tbl(tytys), otype, true)
        if not ok then
            local t = solv.apply(otype)
            local tbl = ty.get_tbl(t)
            if tbl then
                for _, tk in ipairs(tbl) do
                    if tk[2] == field then
                        tk[1] = ty["or"](tk[1], rtype)
                        solv.extend(otype, t)
                        return 
                    end
                end
                local param = node.obj.name
                if param then
                    if param == "@" then
                        param = "self"
                    end
                    t = ty.clone(t)
                    tbl = ty.get_tbl(t)
                    tbl[#tbl + 1] = tytys[1]
                    if not scope.update_var(param, solv.extend(new(), t)) then
                        warn(node.line, node.col, 1, "Fail to add field `" .. field .. "` to undeclared table `" .. param .. "`")
                    end
                end
            end
        end
    end
    Stmt[TStmt.Assign] = function(node)
        balance_check(node.lefts, node.rights)
        local rtypes = infer_exprs(node.rights)
        for i, n in ipairs(node.lefts) do
            local rtype = rtypes[i] or ty["nil"]()
            local ltype
            if n.tag == TExpr.Id then
                ltype = infer_expr(n)
                if not solv.unify(ltype, rtype, true) then
                    solv.extend(ltype, ty["or"](solv.apply(ltype), rtype))
                end
            else
                local ot = infer_expr(n.obj)
                if check(ty.tbl({}), ot, n, "assignment ") then
                    if n.tag == TExpr.Index then
                        local it = infer_expr(n.idx)
                        if it.tag == TExpr.String then
                            assign_field(n, ot, it.value, rtype)
                        end
                    else
                        assign_field(n, ot, n.field, rtype)
                    end
                end
            end
        end
    end
    Stmt[TStmt.Do] = function(node)
        check_block(node.body)
    end
    Stmt[TStmt.If] = function(node)
        for i = 1, #node.tests do
            infer_expr(node.tests[i])
            check_block(node.thenss[i])
        end
        if node.elses then
            check_block(node.elses)
        end
    end
    Stmt[TStmt.Forin] = function(node)
        scope.enter_forin()
        check_types(node.types, node)
        infer_exprs(node.exprs)
        for i, var in ipairs(node.vars) do
            declare(var, node.types and node.types[i])
        end
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.Fornum] = function(node)
        scope.enter_fornum()
        local msg = " expression in numeric for "
        check(ty.num(), infer_expr(node.first), node, "first " .. msg)
        check(ty.num(), infer_expr(node.last), node, "second " .. msg)
        if node.step then
            check(ty.num(), infer_expr(node.step), node, "third " .. msg)
        end
        declare(node.var, ty.num())
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.While] = function(node)
        scope.enter_while()
        infer_expr(node.test)
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.Repeat] = function(node)
        scope.enter_repeat()
        scope.enter()
        check_stmts(node.body)
        infer_expr(node.test)
        scope.leave()
        scope.leave()
    end
    Stmt[TStmt.Return] = function(node)
        local now = ty.tuple(infer_exprs(node.exprs))
        local prev = scope.get_returns()
        if prev then
            now = ty["or"](prev, now)
        end
        scope.set_returns(now)
    end
    Stmt[TStmt.Break] = function(node)
        scope.new_break(node.line, node.col)
    end
    Stmt[TStmt.Goto] = function(node)
        scope.new_goto(node.name, node.line, node.col)
    end
    Stmt[TStmt.Label] = function(node)
        scope.new_label(node.name, node.line, node.col)
    end
    scope.begin_func()
    scope.varargs()
    check_block(stmts)
    local rtuple = scope.get_returns()
    scope.end_func()
    if rtuple and rtuple[1] then
        return solv.apply(rtuple[1])
    end
    return ty["nil"]()
end
