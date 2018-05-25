--
-- Generated from check.lt
--
local ast = require("lua.ast")
local Tag = require("lua.tag")
local subst = require("lua.substitute")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
return function(scope, stmts, warn)
    local Stmt = {}
    local Expr = {}
    local Type = {}
    local fail = function(node)
        warn(node.line, node.col, 3, (node.tag or "nil") .. " cannot match a statement type")
    end
    local check_block = function(nodes, subs)
        local nsubs = subs
        scope.enter_block()
        for _, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            if rule then
                nsubs = rule(node, nsubs)
            else
                fail(node)
            end
        end
        scope.leave_block()
        return nsubs
    end
    local type_expr = function(node, subs)
        local rule = Expr[node.tag]
        return rule(node, subs)
    end
    local type_exprs = function(nodes, subs)
        local types = {}
        local nsubs = subs
        for i, node in ipairs(nodes) do
            types[i], nsubs = type_expr(node, nsubs)
        end
        return types, nsubs
    end
    local declare = function(var, vtype)
        assert(var.tag == TExpr.Id)
        scope.new_var(var.name, vtype, var.line, var.col)
    end
    Type[TType.Tbl] = function(node, subs)
        local vals = {}
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            local key = vk[2]
            if key then
                for n = 1, #keys do
                    if keys[n] and ast.same(keys[n], key) then
                        warn(key.line, key.col, 1, "duplicate keys at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
            end
            keys[i] = key
            local val = vk[1]
            if val and not key then
                for n = 1, #vals do
                    if vals[n] and ast.same(vals[n], val) then
                        warn(val.line, val.col, 1, "similar value types at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
                vals[i] = val
            end
        end
        return ast.Type.table({}, node), subs
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
        return ast.varargs(ast.Type.any(node)), subs
    end
    Expr[TExpr.Id] = function(node, subs)
        local line, ty
        if node.name then
            line, ty = scope.declared(node.name)
            if line == 0 then
                warn(node.line, node.col, 1, "undeclared identifier `" .. node.name .. "`")
            end
            if not ty then
                ty = ast.Type.new(node)
            end
        end
        return ty, subs
    end
    Expr[TExpr.Function] = function(node, subs)
        scope.begin_func()
        local ptypes = {}
        for i, var in ipairs(node.params) do
            local vtype = node.types[i] or ast.Type.new(node)
            if var.tag == TExpr.Vararg then
                scope.varargs()
                ptypes[i] = ast.varargs(vtype)
            else
                declare(var, vtype)
                ptypes[i] = vtype
            end
        end
        local rtypes = check_block(node.body, subs)
        scope.end_func()
        return ast.Type.func(ptypes, rtypes, node), subs
    end
    Expr[TExpr.Table] = function(node, subs)
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            type_expr(vk[1])
            local key = vk[2]
            if key then
                type_expr(key)
                for n = 1, #keys do
                    if keys[n] and ast.same(key, keys[n]) then
                        warn(key.line, key.col, 1, "duplicate keys at position " .. i .. " and " .. n .. " in table")
                    end
                end
            end
            keys[i] = key
        end
        return ast.Type.tbl({}, node), subs
    end
    Expr[TExpr.Index] = function(node, subs)
        local ty, nsubs = type_expr(node.idx, subs)
        return type_expr(node.obj, nsubs), nsubs
    end
    Expr[TExpr.Property] = function(node, subs)
        type_expr(node.obj)
    end
    Expr[TExpr.Invoke] = function(node, subs)
        type_expr(node.obj)
        type_exprs(node.args)
    end
    Expr[TExpr.Call] = function(node, subs)
        type_expr(node.func)
        type_exprs(node.args)
    end
    Expr[TExpr.Unary] = function(node, subs)
        type_expr(node.left)
    end
    Expr[TExpr.Binary] = function(node, subs)
        type_expr(node.left)
        type_expr(node.right)
    end
    Stmt[TStmt.Expr] = function(node, subs)
        return type_expr(node.expr), subs
    end
    local assign_check = function(lefts, ltypes, rights, rtypes, subs)
        local r = #rights
        local l = #lefts
        if r > l then
            warn(rights[1].line, rights[1].col, 1, "assigning " .. r .. " values to " .. l .. " variable(s)")
        end
        local nsubs = subs
        for i, ty in ipairs(ltypes) do
            
        end
        return nsubs
    end
    Stmt[TStmt.Local] = function(node, subs)
        local rtypes = type_exprs(node.exprs)
        local ltypes = {}
        for i, var in ipairs(node.vars) do
            ltypes[i] = node.types[i] or ast.Type.new(var)
            declare(var, ltypes[i])
        end
        return assign_check(node.vars, ltypes, node.exprs, rtypes, subs)
    end
    Stmt[TStmt.Assign] = function(node, subs)
        local ltypes = type_exprs(node.lefts)
        local rtypes = type_exprs(node.rights)
        assign_check(node.lefts, ltypes, node.rights, rtypes)
    end
    Stmt[TStmt.Do] = function(node, subs)
        check_block(node.body)
    end
    Stmt[TStmt.If] = function(node, subs)
        for i = 1, #node.tests do
            type_expr(node.tests[i])
            check_block(node.thenss[i])
        end
        if node.elses then
            check_block(node.elses)
        end
    end
    Stmt[TStmt.Forin] = function(node, subs)
        scope.enter_block("ForIn")
        type_exprs(node.exprs)
        for i, var in ipairs(node.vars) do
            declare(var, node.types[i])
        end
        check_block(node.body)
        scope.leave_block()
        return nil, subs
    end
    Stmt[TStmt.Fornum] = function(node, subs)
        scope.enter_block("ForNum")
        type_expr(node.first)
        type_expr(node.last)
        if node.step then
            type_expr(node.step)
        end
        declare(node.var, ast.Type.num(node))
        check_block(node.body)
        scope.leave_block()
        return nil, subs
    end
    Stmt[TStmt.While] = function(node, subs)
        scope.enter_block("While")
        type_expr(node.test)
        check_block(node.body)
        scope.leave_block()
        return nil, subs
    end
    Stmt[TStmt.Repeat] = function(node, subs)
        scope.enter_block("Repeat")
        scope.enter_block()
        for _, node in ipairs(node.body) do
            local rule = Stmt[node.tag]
            if rule then
                nsubs = rule(node, nsubs)
            else
                fail(node)
            end
        end
        type_expr(node.test)
        scope.leave_block()
        scope.leave_block()
        return nil, subs
    end
    Stmt[TStmt.Return] = function(node, subs)
        return type_exprs(node.exprs), subs
    end
    Stmt[TStmt.Break] = function(node, subs)
        scope.new_break(node.line, node.col)
        return nil, subs
    end
    Stmt[TStmt.Goto] = function(node, subs)
        scope.new_goto(node.name, node.line, node.col)
        return nil, subs
    end
    Stmt[TStmt.Label] = function(node, subs)
        scope.new_label(node.name, node.line, node.col)
        return nil, subs
    end
    scope.begin_func()
    scope.varargs()
    local types, subs = check_block(stmts, {})
    scope.end_func()
end
