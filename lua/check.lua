--
-- Generated from check.lt
--
local ast = require("lua.ast")
local typ = require("lua.type")
local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
return function(scope, stmts, warn)
    local Stmt = {}
    local Expr = {}
    local Type = {}
    local ty = typ(warn)
    local fail = function(node)
        local msg = (node.tag or "nil") .. " cannot match a statement type"
        if node.line and node.col then
            warn(node.line, node.col, 3, msg)
        else
            error(msg)
        end
    end
    local check_type = function(tnode)
        local rule = Type[tnode.tag]
        if rule then
            rule(tnode)
        end
    end
    local check_types = function(tnodes)
        if tnodes then
            for _, node in ipairs(tnodes) do
                check_type(node)
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
    Type[TType.Tuple] = function(node)
        check_types(node.types)
    end
    Type[TType.Ref] = function(node)
        if node.params then
            
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
                        check_type(key)
                        for n = 1, #keys do
                            if keys[n] and ast.same(keys[n], key) then
                                dup = n
                            end
                        end
                    end
                    if dup > 0 then
                        warn(key.line, key.col, 1, "duplicate key types at position " .. i .. " and " .. dup .. " in table type annotation")
                    end
                end
                keys[i] = key
                local vt = vk[1]
                check_type(vt)
                if vt and not key then
                    for n = 1, #vtypes do
                        if vtypes[n] and ast.same(vtypes[n], vt) then
                            warn(vt.line, vt.col, 1, "similar value types at position " .. i .. " and " .. n .. " in table type annotation")
                        end
                    end
                    vtypes[i] = vt
                end
            end
        end
    end
    Expr[TExpr.Nil] = function(node)
        return ast.Type["nil"](node)
    end
    Expr[TExpr.Bool] = function(node)
        return ast.Type.bool(node)
    end
    Expr[TExpr.Number] = function(node)
        return ast.Type.num(node)
    end
    Expr[TExpr.String] = function(node)
        return ast.Type.str(node)
    end
    Expr[TExpr.Vararg] = function(node)
        if not scope.is_varargs() then
            warn(node.line, node.col, 2, "cannot use `...` in a function without variable arguments")
        end
        local t = ast.Type.any(node)
        ast.varargs(t)
        return t
    end
    Expr[TExpr.Id] = function(node)
        local line, t
        if node.name then
            line, t = scope.declared(node.name)
            if line == 0 then
                warn(node.line, node.col, 1, "undeclared identifier `" .. node.name .. "`")
            end
            if not t then
                t = ast.Type.new(node)
            end
        end
        return t
    end
    Expr[TExpr.Function] = function(node)
        scope.begin_func()
        check_types(node.types)
        check_types(node.retypes)
        for i, p in ipairs(node.params) do
            local t = node.types and node.types[i] or ast.Type.new(p)
            if p.tag == TExpr.Vararg then
                scope.varargs()
                ast.varargs(t)
            else
                declare(p, t)
            end
        end
        scope.set_returns(node.retypes)
        check_block(node.body)
        local ptypes = {}
        for i, p in ipairs(node.params) do
            ptypes[i] = ty.apply(infer_expr(p))
            if node.types and node.types[i] then
                ty.unify(ptypes[i], node.types[i])
                ptypes[i] = node.types[i]
            end
        end
        scope.end_func()
        return ast.Type.func(ast.Type.tuple(ptypes, node), ast.Type.tuple(scope.get_returns() or {}, node), node)
    end
    Expr[TExpr.Table] = function(node)
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            local key = vk[2]
            if key then
                for n = 1, #keys do
                    if keys[n] and ast.same(keys[n], key) then
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
                elseif not ast.same(vtype, vt) then
                    vtype = nil
                end
            end
        end
        if vtype then
            tytys[#tytys + 1] = {vtype, nil}
        end
        local tbl = ast.Type.tbl(tytys, node)
        check_type(tbl)
        return tbl
    end
    Expr[TExpr.Index] = function(node)
        local it, ot
        it = infer_expr(node.idx)
        ot = infer_expr(node.obj)
        ty.unify(ot, ast.Type.tbl({}, node.obj))
        return ast.Type.any(node)
    end
    Expr[TExpr.Property] = function(node)
        local ot
        ot = infer_expr(node.obj)
        local vt = ast.Type.new(node.obj)
        local tytys = {{vt, node.prop}}
        ty.unify(ot, ast.Type.tbl(tytys, node.obj))
        return ty.apply(vt)
    end
    Expr[TExpr.Invoke] = function(node)
        local atypes, ot
        atypes = infer_exprs(node.args)
        ot = infer_expr(node.obj)
        local retype = ast.Type.new(node.obj)
        local tytys = {{ast.Type.func(ast.Type.tuple(atypes, node), ast.Type.tuple({retype}, node.obj), node.obj), node.prop}}
        ty.unify(ot, ast.Type.tbl(tytys, node.obj))
        return ty.apply(retype)
    end
    Expr[TExpr.Call] = function(node)
        local atypes, ftype
        atypes = infer_exprs(node.args)
        ftype = infer_expr(node.func)
        local retype = ast.Type.new(node.func)
        ty.unify(ftype, ast.Type.func(ast.Type.tuple(atypes, node), ast.Type.tuple({retype}, node.func), node))
        return ty.apply(retype)
    end
    Expr[TExpr.Unary] = function(node)
        local rtype
        rtype = infer_expr(node.right)
        local op = node.op
        if op == "#" then
            ty.unify(ast.Type.tbl({}, node), rtype)
            return ast.Type.num(node)
        end
        if op == "-" then
            ty.unify(ast.Type.num(node), rtype)
            return ast.Type.num(node)
        end
        return ast.Type.bool(node)
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
            ty.unify(rtype, ltype)
            if op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" then
                return ast.Type.bool(node)
            end
        end
        return ltype
    end
    Stmt[TStmt.Expr] = function(node)
        local etype
        etype = infer_expr(node.expr)
    end
    Stmt[TStmt.Local] = function(node)
        check_types(node.types)
        balance_check(node.vars, node.exprs)
        local rtypes
        rtypes = infer_exprs(node.exprs)
        for i, var in ipairs(node.vars) do
            local ltype = node.types and node.types[i]
            if ltype then
                ty.unify(ltype, rtypes[i])
            else
                ltype = rtypes[i]
                if not ltype then
                    ltype = ast.Type.new(var)
                    ast.nils(ltype)
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
            ty.unify(ltype, rtypes[i] or ast.Type["nil"](node.rights[i] or ast.Expr["nil"](node)))
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
        check_types(node.types)
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
        declare(node.var, ast.Type.num(node.var))
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
                    ty.unify(r, types[i])
                end
            end
        else
            scope.set_returns(ast.Type.tuple(types, node))
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
