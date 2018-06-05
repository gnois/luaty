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
        for _, node in ipairs(tnodes) do
            check_type(node)
        end
    end
    local check_stmts = function(nodes, subs)
        for _, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            if rule then
                subs = rule(node, subs)
            else
                fail(node)
            end
        end
        return subs
    end
    local check_block = function(nodes, subs)
        scope.enter()
        subs = check_stmts(nodes, subs)
        scope.leave()
        return subs
    end
    local infer_expr = function(node, subs)
        local rule = Expr[node.tag]
        return rule(node, subs)
    end
    local infer_exprs = function(nodes, subs)
        local types = {}
        for i, node in ipairs(nodes) do
            types[i], subs = infer_expr(node, subs)
        end
        return types, subs
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
    Type[TType.Tbl] = function(node)
        local vtypes = {}
        local keys = {}
        for i, vk in ipairs(node.typekeys) do
            local key = vk[2]
            if key then
                check_type(key)
                for n = 1, #keys do
                    if keys[n] and ast.same(keys[n], key) then
                        warn(key.line, key.col, 1, "duplicate keys at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
            end
            keys[i] = key
            local vtype = vk[1]
            check_type(vtype)
            if vtype and not key then
                for n = 1, #vtypes do
                    if vtypes[n] and ast.same(vtypes[n], vtype) then
                        warn(vtype.line, vtype.col, 1, "similar value types at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
                vtypes[i] = vtype
            end
        end
    end
    Expr[TExpr.Nil] = function(node, subs)
        return ast.Type["nil"](node), subs
    end
    Expr[TExpr.Bool] = function(node, subs)
        return ast.Type.bool(node), subs
    end
    Expr[TExpr.Number] = function(node, subs)
        return ast.Type.num(node), subs
    end
    Expr[TExpr.String] = function(node, subs)
        return ast.Type.str(node), subs
    end
    Expr[TExpr.Vararg] = function(node, subs)
        if not scope.is_varargs() then
            warn(node.line, node.col, 2, "cannot use `...` in a function without variable arguments")
        end
        local t = ast.Type.any(node)
        ast.varargs(t)
        return t, subs
    end
    Expr[TExpr.Id] = function(node, subs)
        local line, vtype
        if node.name then
            line, vtype = scope.declared(node.name)
            if line == 0 then
                warn(node.line, node.col, 1, "undeclared identifier `" .. node.name .. "`")
            end
            if not vtype then
                vtype = ast.Type.new(node)
            end
        end
        return vtype, subs
    end
    Expr[TExpr.Function] = function(node, subs)
        scope.begin_func()
        check_types(node.types)
        check_types(node.retypes)
        for i, var in ipairs(node.params) do
            local vtype = node.types[i] or ast.Type.new(var)
            if var.tag == TExpr.Vararg then
                scope.varargs()
                ast.varargs(vtype)
            else
                declare(var, vtype)
            end
        end
        scope.set_returns(node.retypes)
        subs = check_block(node.body, subs)
        local ptypes = {}
        for i, var in ipairs(node.params) do
            ptypes[i] = ty.apply(infer_expr(var, subs), subs)
            if node.types[i] then
                subs = ty.unify(subs, ptypes[i], node.types[i])
                ptypes[i] = node.types[i]
            end
        end
        scope.end_func()
        return ast.Type.func(ptypes, scope.get_returns(), node), subs
    end
    Expr[TExpr.Table] = function(node, subs)
        local typekeys = {}
        local vtyped = false
        local vtype
        for i, vk in ipairs(node.valkeys) do
            local vt
            vt, subs = infer_expr(vk[1], subs)
            local key = vk[2]
            if key then
                for n, tk in ipairs(typekeys) do
                    if ast.same(key, tk[2]) then
                        warn(key.line, key.col, 1, "duplicate key at position " .. i .. " and " .. n .. " in table")
                    end
                end
                typekeys[i] = {vt, key}
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
            typekeys[#typekeys + 1] = {vtype, nil}
        end
        return ast.Type.tbl(typekeys, node), subs
    end
    Expr[TExpr.Index] = function(node, subs)
        local itype, otype
        itype, subs = infer_expr(node.idx, subs)
        otype, subs = infer_expr(node.obj, subs)
        subs = ty.unify(subs, otype, ast.Type.tbl({}, node.obj))
        return ast.Type.any(node), subs
    end
    Expr[TExpr.Property] = function(node, subs)
        local otype
        otype, subs = infer_expr(node.obj, subs)
        local vtype = ast.Type.new(node.obj)
        local typekeys = {{vtype, node.prop}}
        subs = ty.unify(subs, otype, ast.Type.tbl(typekeys, node.obj))
        return ty.apply(vtype, subs), subs
    end
    Expr[TExpr.Invoke] = function(node, subs)
        local atypes, otype
        atypes, subs = infer_exprs(node.args, subs)
        otype, subs = infer_expr(node.obj, subs)
        local retype = ast.Type.new(node.obj)
        ast.varargs(retype)
        local typekeys = {{ast.Type.func(atypes, {retype}, node.obj), node.prop}}
        subs = ty.unify(subs, otype, ast.Type.tbl(typekeys, node.obj))
        return ty.apply(retype, subs), subs
    end
    Expr[TExpr.Call] = function(node, subs)
        local atypes, ftype
        atypes, subs = infer_exprs(node.args, subs)
        ftype, subs = infer_expr(node.func, subs)
        local retype = ast.Type.new(node.func)
        ast.varargs(retype)
        subs = ty.unify(subs, ftype, ast.Type.func(atypes, {retype}, node))
        return ty.apply(retype, subs), subs
    end
    Expr[TExpr.Unary] = function(node, subs)
        local rtype
        rtype, subs = infer_expr(node.right, subs)
        local op = node.op
        if op == "#" then
            return ast.Type.num(node), ty.unify(subs, ast.Type.tbl({}, node), rtype)
        end
        if op == "-" then
            return ast.Type.num(node), ty.unify(subs, ast.Type.num(node), rtype)
        end
        return ast.Type.bool(node), subs
    end
    Expr[TExpr.Binary] = function(node, subs)
        local rtype, ltype
        rtype, subs = infer_expr(node.right, subs)
        ltype, subs = infer_expr(node.left, subs)
        local op = node.op
        if op == "and" then
            return rtype, subs
        end
        if op == "+" or op == "-" or op == "*" or op == "/" or op == "^" or op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" or op == ".." then
            subs = ty.unify(subs, rtype, ltype)
            if op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" then
                return ast.Type.bool(node), subs
            end
        end
        return ltype, subs
    end
    Stmt[TStmt.Expr] = function(node, subs)
        local etype
        etype, subs = infer_expr(node.expr, subs)
        return subs
    end
    Stmt[TStmt.Local] = function(node, subs)
        check_types(node.types)
        balance_check(node.vars, node.exprs)
        local rtypes
        rtypes, subs = infer_exprs(node.exprs, subs)
        for i, var in ipairs(node.vars) do
            local ltype = node.types[i]
            if ltype then
                subs = ty.unify(subs, ltype, rtypes[i])
            else
                ltype = rtypes[i]
                if not ltype then
                    ltype = ast.Type.new(var)
                    ast.nils(ltype)
                end
            end
            declare(var, ltype)
        end
        return subs
    end
    Stmt[TStmt.Assign] = function(node, subs)
        balance_check(node.lefts, node.rights)
        local rtypes, ltypes
        rtypes, subs = infer_exprs(node.rights, subs)
        ltypes, subs = infer_exprs(node.lefts, subs)
        for i, ltype in ipairs(ltypes) do
            subs = ty.unify(subs, ltype, rtypes[i] or ast.Type["nil"](node.rights[i] or ast.Expr["nil"](node)))
        end
        return subs
    end
    Stmt[TStmt.Do] = function(node, subs)
        return check_block(node.body, subs)
    end
    Stmt[TStmt.If] = function(node, subs)
        for i = 1, #node.tests do
            infer_expr(node.tests[i], subs)
            subs = check_block(node.thenss[i], subs)
        end
        if node.elses then
            subs = check_block(node.elses, subs)
        end
        return subs
    end
    Stmt[TStmt.Forin] = function(node, subs)
        scope.enter_forin()
        check_types(node.types)
        local types
        types, subs = infer_exprs(node.exprs, subs)
        for i, var in ipairs(node.vars) do
            declare(var, node.types[i])
        end
        subs = check_block(node.body, subs)
        scope.leave()
        return subs
    end
    Stmt[TStmt.Fornum] = function(node, subs)
        scope.enter_fornum()
        infer_expr(node.first, subs)
        infer_expr(node.last, subs)
        if node.step then
            infer_expr(node.step, subs)
        end
        declare(node.var, ast.Type.num(node.var))
        subs = check_block(node.body, subs)
        scope.leave()
        return subs
    end
    Stmt[TStmt.While] = function(node, subs)
        scope.enter_while()
        infer_expr(node.test, subs)
        subs = check_block(node.body, subs)
        scope.leave()
        return subs
    end
    Stmt[TStmt.Repeat] = function(node, subs)
        scope.enter_repeat()
        scope.enter()
        subs = check_stmts(node.body, subs)
        infer_expr(node.test, subs)
        scope.leave()
        scope.leave()
        return subs
    end
    Stmt[TStmt.Return] = function(node, subs)
        local types
        types, subs = infer_exprs(node.exprs, subs)
        local rtypes = scope.get_returns()
        if #rtypes > 0 then
            for i, r in ipairs(rtypes) do
                if types[i] then
                    subs = ty.unify(subs, r, types[i])
                end
            end
        else
            scope.set_returns(types)
        end
        return subs
    end
    Stmt[TStmt.Break] = function(node, subs)
        scope.new_break(node.line, node.col)
        return subs
    end
    Stmt[TStmt.Goto] = function(node, subs)
        scope.new_goto(node.name, node.line, node.col)
        return subs
    end
    Stmt[TStmt.Label] = function(node, subs)
        scope.new_label(node.name, node.line, node.col)
        return subs
    end
    scope.begin_func()
    scope.varargs()
    check_block(stmts, {})
    scope.end_func()
end
