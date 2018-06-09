--
-- Generated from check.lt
--
local ty = require("lua.type")
local Tag = require("lua.tag")
local solv = require("lua.solve")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
return function(scope, stmts, warn)
    local Stmt = {}
    local Expr = {}
    local Type = {}
    local fail = function(node)
        local msg = (node.tag or "nil") .. " cannot match a statement type"
        if node.line and node.col then
            warn(node.line, node.col, 3, msg)
        else
            error(msg)
        end
    end
    local check = function(x, y, node, msg)
        local ok, err = solv.unify(x, y)
        if not ok then
            warn(node.line, node.col, 1, (msg or "") .. err)
        end
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
    local infer_exprs = function(nodes)
        local types = {}
        for i, node in ipairs(nodes) do
            types[i] = infer_expr(node)
        end
        return types
    end
    local declare = function(var, vtype)
        assert(var.tag == TExpr.Id)
        scope.new_var(var.name, vtype, var.line, var.col)
    end
    local balance_check = function(lefts, rights)
        local r = #rights
        local l = #lefts
        if r > l then
            warn(rights[1].line, rights[1].col, 1, "assigning " .. r .. " values to " .. l .. " variable(s)")
        end
    end
    Type[TType.Tuple] = function(node, loc)
        check_types(node.types, loc)
    end
    Type[TType.Ref] = function(node, loc)
        if node.ins then
            
        end
        if node.tytys then
            local vtypes = {}
            local keys = {}
            for i, vk in ipairs(node.tytys) do
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
    end
    Expr[TExpr.Nil] = function(node)
        return ty["nil"]()
    end
    Expr[TExpr.Bool] = function(node)
        return ty.bool()
    end
    Expr[TExpr.Number] = function(node)
        return ty.num()
    end
    Expr[TExpr.String] = function(node)
        return ty.str()
    end
    Expr[TExpr.Vararg] = function(node)
        if not scope.is_varargs() then
            warn(node.line, node.col, 2, "cannot use `...` in a function without variable arguments")
        end
        return ty.varargs(ty.any())
    end
    Expr[TExpr.Id] = function(node)
        local line, t
        if node.name then
            line, t = scope.declared(node.name)
            if line == 0 then
                warn(node.line, node.col, 1, "undeclared identifier `" .. node.name .. "`")
            end
            if not t then
                t = ty.new()
            end
        end
        return t
    end
    Expr[TExpr.Function] = function(node)
        scope.begin_func()
        check_types(node.types, node)
        check_types(node.retypes, node)
        for i, p in ipairs(node.params) do
            local t = node.types and node.types[i] or ty.new()
            if p.tag == TExpr.Vararg then
                scope.varargs()
                t = ty.varargs(t)
            else
                declare(p, t)
            end
        end
        scope.set_returns(node.retypes)
        check_block(node.body)
        local ptypes = {}
        for i, p in ipairs(node.params) do
            ptypes[i] = solv.apply(infer_expr(p))
            if node.types and node.types[i] then
                check(ptypes[i], node.types[i], p, "parameter type annotation ")
                ptypes[i] = node.types[i]
            end
        end
        scope.end_func()
        return ty.func(ty.tuple(ptypes), ty.tuple(scope.get_returns() or {}))
    end
    Expr[TExpr.Table] = function(node)
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            local key = vk[2]
            if key then
                for n = 1, #keys do
                    if keys[n] and ty.same(keys[n], key) then
                        warn(key.line, key.col, 10, "duplicate keys at position " .. i .. " and " .. n .. " in table")
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
        local it, ot
        it = infer_expr(node.idx)
        ot = infer_expr(node.obj)
        check(ot, ty.tbl({}), node)
        return ty.any()
    end
    Expr[TExpr.Property] = function(node)
        local ot
        ot = infer_expr(node.obj)
        local vt = ty.new()
        local tytys = {{vt, node.prop}}
        check(ot, ty.tbl(tytys), node, "index operator ")
        return solv.apply(vt)
    end
    Expr[TExpr.Invoke] = function(node)
        local atypes, ot
        atypes = infer_exprs(node.args)
        ot = infer_expr(node.obj)
        local retype = ty.new()
        local tytys = {{ty.func(ty.tuple(atypes), ty.tuple({retype})), node.prop}}
        check(ot, ty.tbl(tytys), node, "method invocation ")
        return solv.apply(retype)
    end
    Expr[TExpr.Call] = function(node)
        local atypes, ftype
        atypes = infer_exprs(node.args)
        ftype = infer_expr(node.func)
        local retype = ty.new()
        check(ftype, ty.func(ty.tuple(atypes), ty.tuple({retype})), node, "function call ")
        return solv.apply(retype)
    end
    Expr[TExpr.Unary] = function(node)
        local rtype
        rtype = infer_expr(node.right)
        local op = node.op
        if op == "#" then
            check(rtype, ty["or"](ty.tbl({}), ty.str()), node, op .. " operator ")
            return ty.num()
        end
        if op == "-" then
            check(rtype, ty.num(), node, op .. " operator ")
            return ty.num()
        end
        return ty.bool()
    end
    Expr[TExpr.Binary] = function(node)
        local rtype, ltype
        rtype = infer_expr(node.right)
        ltype = infer_expr(node.left)
        local op = node.op
        if op == "and" then
            return rtype
        end
        if op == "+" or op == "-" or op == "*" or op == "/" or op == "^" or op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" or op == ".." then
            check(rtype, ltype, node, op .. " operator ")
            if op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" then
                return ty.bool()
            end
        end
        return ltype
    end
    Stmt[TStmt.Expr] = function(node)
        local etype
        etype = infer_expr(node.expr)
    end
    Stmt[TStmt.Local] = function(node)
        check_types(node.types, node)
        balance_check(node.vars, node.exprs)
        local rtypes
        rtypes = infer_exprs(node.exprs)
        for i, var in ipairs(node.vars) do
            local ltype = node.types and node.types[i]
            if ltype then
                check(ltype, rtypes[i], node, "type annotation ")
            else
                ltype = rtypes[i]
                if not ltype then
                    ltype = ty.new()
                end
            end
            declare(var, ltype)
        end
    end
    Stmt[TStmt.Assign] = function(node)
        balance_check(node.lefts, node.rights)
        local rtypes, ltypes
        rtypes = infer_exprs(node.rights)
        ltypes = infer_exprs(node.lefts)
        for i, ltype in ipairs(ltypes) do
            check(ltype, rtypes[i] or ty["nil"](), node, "assigment ")
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
        local types
        types = infer_exprs(node.exprs)
        for i, var in ipairs(node.vars) do
            declare(var, node.types and node.types[i])
        end
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.Fornum] = function(node)
        scope.enter_fornum()
        infer_expr(node.first)
        infer_expr(node.last)
        if node.step then
            infer_expr(node.step)
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
        local types
        types = infer_exprs(node.exprs)
        local rtuple = scope.get_returns()
        if rtuple then
            for i, r in ipairs(rtuple.types) do
                if types[i] then
                    check(r, types[i], node.exprs[i] or node, "return type ")
                end
            end
        else
            scope.set_returns(ty.tuple(types))
        end
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
    scope.end_func()
end
