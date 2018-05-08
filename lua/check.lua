--
-- Generated from check.lt
--


local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
local same
same = function(a, b)
    if a and b and a.tag == b.tag then
        if #a ~= #b then
            return false
        end
        local last = 1
        for i, v in ipairs(a) do
            last = i
            if "table" == type(v) then
                if not same(v, b[i]) then
                    return false
                end
            elseif b[i] ~= v then
                return false
            end
        end
        for k, v in pairs(a) do
            if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
                if k ~= "line" and k ~= "col" then
                    if "table" == type(v) then
                        if not same(v, b[k]) then
                            return false
                        end
                    elseif b[k] ~= v then
                        return false
                    end
                end
            end
        end
        for k, v in pairs(b) do
            if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
                if k ~= "line" and k ~= "col" then
                    if "table" == type(v) then
                        if not same(v, a[k]) then
                            return false
                        end
                    elseif a[k] ~= v then
                        return false
                    end
                end
            end
        end
        return true
    end
    return false
end
return function(scope, stmts, warn)
    local Stmt = {}
    local Expr = {}
    local Type = {}
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
        scope.new_var(var.name, vtype, var.line, var.col)
    end
    Type[TType.Tbl] = function(node)
        local vals = {}
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            local key = vk[2]
            if key then
                for n = 1, #keys do
                    if keys[n] and same(keys[n], key) then
                        warn(key.line, key.col, 10, "duplicate keys at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
            end
            keys[i] = key
            local val = vk[1]
            if val and not key then
                for n = 1, #vals do
                    if vals[n] and same(vals[n], val) then
                        warn(val.line, val.col, 10, "similar value types at position " .. i .. " and " .. n .. " in table type annotation")
                    end
                end
                vals[i] = val
            end
        end
    end
    Expr[TExpr.Vararg] = function(node)
        if not scope.is_varargs() then
            warn(node.line, node.col, 11, "cannot use `...` in a function without variable arguments")
        end
    end
    Expr[TExpr.Id] = function(node)
        if node.name and scope.declared(node.name) == 0 then
            warn(node.line, node.col, 8, "undeclared identifier `" .. node.name .. "`")
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
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            check_expr(vk[1])
            local key = vk[2]
            if key then
                check_expr(key)
                for n = 1, #keys do
                    if keys[n] and same(key, keys[n]) then
                        warn(key.line, key.col, 10, "duplicate keys at position " .. i .. " and " .. n .. " in table")
                    end
                end
            end
            keys[i] = key
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
    local assign_check = function(lefts, rights)
        local r = #rights
        local l = #lefts
        if r > l then
            warn(rights[1].line, rights[1].col, 9, "assigning " .. r .. " values to " .. l .. " variable(s)")
        end
    end
    Stmt[TStmt.Local] = function(node)
        for _, var in ipairs(node.vars) do
            declare(var)
        end
        check_exprs(node.exprs)
        assign_check(node.vars, node.exprs)
    end
    Stmt[TStmt.Assign] = function(node)
        check_exprs(node.lefts)
        check_exprs(node.rights)
        assign_check(node.lefts, node.rights)
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
