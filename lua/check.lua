--
-- Generated from check.lt
--

local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
return function(scope, stmts, warn)
    local Stmt = {}
    local Expr = {}
    local check_block = function(nodes)
        scope.enter_block()
        for _, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            if rule then
                rule(node)
            end
        end
        scope.leave_block()
    end
    local check_expr = function(node)
        local rule = Expr[node.tag]
        if rule then
            rule(node)
        end
    end
    local check_exprs = function(nodes)
        for _, node in ipairs(nodes) do
            check_expr(node)
        end
    end
    local declare = function(var, vtype)
        assert(var.tag == TExpr.Id)
        scope.new_var(var.name, vtype, var.line)
    end
    Expr[TExpr.Vararg] = function(node)
        if not scope.is_varargs() then
            warn(node.line, 1, 11, "cannot use `...` in a function without variable arguments")
        end
    end
    Expr[TExpr.Id] = function(node)
        if scope.declared(node.name) == 0 then
            warn(node.line, 1, 10, "undeclared identifier `" .. node.name .. "`")
        end
    end
    Expr[TExpr.Function] = function(node)
        scope.begin_func()
        for _, var in ipairs(node.params) do
            if var.tag == TExpr.Vararg then
                scope.varargs()
            else
                declare(var)
            end
        end
        check_block(node.body)
        scope.end_func()
    end
    Expr[TExpr.Table] = function(node)
        for _, kv in ipairs(node.keyvals) do
            check_expr(kv[1])
            if kv[2] then
                check_expr(kv[2])
            end
        end
    end
    Expr[TExpr.Index] = function(node)
        check_expr(node.obj)
        check_expr(node.idx)
    end
    Expr[TExpr.Property] = function(node)
        check_expr(node.obj)
    end
    Expr[TExpr.Invoke] = function(node)
        check_expr(node.obj)
        check_exprs(node.args)
    end
    Expr[TExpr.Call] = function(node)
        check_expr(node.func)
        check_exprs(node.args)
    end
    Expr[TExpr.Unary] = function(node)
        check_expr(node.left)
    end
    Expr[TExpr.Binary] = function(node)
        check_expr(node.left)
        check_expr(node.right)
    end
    Stmt[TStmt.Expr] = function(node)
        check_expr(node.expr)
    end
    Stmt[TStmt.Local] = function(node)
        for _, var in ipairs(node.vars) do
            declare(var)
        end
        check_exprs(node.exprs)
    end
    Stmt[TStmt.Assign] = function(node)
        check_exprs(node.lefts)
        check_exprs(node.rights)
    end
    Stmt[TStmt.Do] = function(node)
        check_block(node.body)
    end
    Stmt[TStmt.If] = function(node)
        for i = 1, #node.tests do
            check_expr(node.tests[i])
            check_block(node.thenss[i])
        end
        if node.elses then
            check_block(node.elses)
        end
    end
    Stmt[TStmt.Forin] = function(node)
        scope.enter_block("ForIn")
        check_exprs(node.exprs)
        for _, var in ipairs(node.vars) do
            declare(var)
        end
        check_block(node.body)
        scope.leave_block()
    end
    Stmt[TStmt.Fornum] = function(node)
        scope.enter_block("ForNum")
        check_expr(node.first)
        check_expr(node.last)
        if node.step then
            check_expr(node.step)
        end
        declare(node.var)
        check_block(node.body)
        scope.leave_block()
    end
    Stmt[TStmt.While] = function(node)
        scope.enter_block("While")
        check_expr(node.test)
        check_block(node.body)
        scope.leave_block()
    end
    Stmt[TStmt.Repeat] = function(node)
        scope.enter_block("Repeat")
        check_block(node.body)
        check_expr(node.test)
        scope.leave_block()
    end
    Stmt[TStmt.Return] = function(node)
        check_exprs(node.exprs)
    end
    Stmt[TStmt.Break] = function(node)
        scope.new_break(node.line)
    end
    Stmt[TStmt.Goto] = function(node)
        scope.new_goto(node.name, node.line)
    end
    Stmt[TStmt.Label] = function(node)
        scope.new_label(node.name, node.line)
    end
    scope.begin_func()
    scope.varargs()
    check_block(stmts)
    scope.end_func()
end