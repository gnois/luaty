--
-- Generated from ast.lt
--

local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local make = function(tag, node, ls)
    assert("table" == type(node))
    assert("number" == type(ls.line))
    assert("number" == type(ls.col))
    node.tag = tag
    node.line = ls.line
    node.col = ls.col
    return node
end
local Statement = {expression = function(expr, ls)
    return make(TStmt.Expr, {expr = expr}, ls)
end, assign = function(lhs, rhs, ls)
    return make(TStmt.Assign, {lefts = lhs, rights = rhs}, ls)
end, ["local"] = function(vars, exprs, ls)
    return make(TStmt.Local, {vars = vars, exprs = exprs}, ls)
end, ["do"] = function(body, ls)
    return make(TStmt.Do, {body = body}, ls)
end, ["if"] = function(tests, thenss, elses, ls)
    return make(TStmt.If, {tests = tests, thenss = thenss, elses = elses}, ls)
end, forin = function(vars, exprs, body, ls)
    return make(TStmt.Forin, {vars = vars, exprs = exprs, body = body}, ls)
end, fornum = function(var, first, last, step, body, ls)
    return make(TStmt.Fornum, {var = var, first = first, last = last, step = step, body = body}, ls)
end, ["while"] = function(test, body, ls)
    return make(TStmt.While, {test = test, body = body}, ls)
end, ["repeat"] = function(test, body, ls)
    return make(TStmt.Repeat, {test = test, body = body}, ls)
end, ["return"] = function(exprs, ls)
    return make(TStmt.Return, {exprs = exprs}, ls)
end, ["break"] = function(ls)
    return make(TStmt.Break, {}, ls)
end, ["goto"] = function(name, ls)
    return make(TStmt.Goto, {name = name}, ls)
end, label = function(name, ls)
    return make(TStmt.Label, {name = name}, ls)
end}
local Expression = {null = function(ls)
    return make(TExpr.Nil, {}, ls)
end, vararg = function(ls)
    return make(TExpr.Vararg, {}, ls)
end, id = function(name, ls)
    return make(TExpr.Id, {name = name}, ls)
end, bool = function(val, ls)
    return make(TExpr.Bool, {value = val}, ls)
end, number = function(val, ls)
    return make(TExpr.Number, {value = val}, ls)
end, string = function(val, long, ls)
    return make(TExpr.String, {value = val, long = long}, ls)
end, ["function"] = function(params, body, vararg, ls)
    return make(TExpr.Function, {body = body, params = params, vararg = vararg}, ls)
end, table = function(keyvals, ls)
    return make(TExpr.Table, {keyvals = keyvals}, ls)
end, index = function(obj, index, ls)
    return make(TExpr.Index, {obj = obj, idx = index}, ls)
end, property = function(obj, prop, ls)
    return make(TExpr.Property, {obj = obj, prop = prop}, ls)
end, invoke = function(obj, prop, args, ls)
    return make(TExpr.Invoke, {obj = obj, prop = prop, args = args}, ls)
end, call = function(func, args, ls)
    return make(TExpr.Call, {func = func, args = args}, ls)
end, unary = function(op, left, ls)
    return make(TExpr.Unary, {op = op, left = left}, ls)
end, binary = function(op, left, right, ls)
    return make(TExpr.Binary, {op = op, left = left, right = right}, ls)
end}
local bracket = function(node)
    assert("table" == type(node))
    node.bracketed = true
    return node
end
local dump = function(stmts)
    local indents = 0
    local indentation = function()
        return "\n" .. string.rep("  ", indents)
    end
    local astr = function(open, close, tag, ...)
        local list = {}
        list[1] = "`" .. tag
        for k, v in ipairs({...}) do
            list[1 + k] = tostring(v)
        end
        return open .. table.concat(list, " ") .. close
    end
    local expr = function(tag, ...)
        return astr("{", "}", tag, ...)
    end
    local stmt = function(tag, ...)
        return astr("[", "]", tag, ...)
    end
    local Stmt = {}
    local Expr = {}
    local visit_stmts = function(nodes)
        local list = {}
        for i, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            list[i] = rule(node)
        end
        local spaces = indentation()
        return spaces .. table.concat(list, spaces)
    end
    local visit_expr = function(node)
        local rule = Expr[node.tag]
        return rule(node)
    end
    local visit_exprs = function(nodes)
        local list = {}
        for i, node in ipairs(nodes) do
            list[i] = visit_expr(node)
        end
        return table.concat(list, " ")
    end
    local block = function(header, nodes)
        indents = indents + 1
        local body = visit_stmts(nodes)
        indents = indents - 1
        return header .. body
    end
    Expr[TExpr.Nil] = function()
        return expr("nil")
    end
    Expr[TExpr.Vararg] = function()
        return expr("dots")
    end
    Expr[TExpr.Id] = function(node)
        return expr("Id", node.name)
    end
    Expr[TExpr.Bool] = function(node)
        return expr("Bool", node.value)
    end
    Expr[TExpr.Number] = function(node)
        return expr("Num", node.value)
    end
    Expr[TExpr.String] = function(node)
        if node.long then
            return expr("LongStr", node.value)
        end
        return expr("Str", node.value)
    end
    Expr[TExpr.Function] = function(node)
        return block(expr("Function", visit_exprs(node.params)), node.body)
    end
    Expr[TExpr.Table] = function(node)
        local body = {}
        local key, val
        for i, kv in ipairs(node.keyvals) do
            val = visit_expr(kv[1])
            if kv[2] then
                key = visit_expr(kv[2])
                body[i] = key .. "=" .. val
            else
                body[i] = val
            end
        end
        return expr("Table", table.concat(body, " "))
    end
    Expr[TExpr.Index] = function(node)
        return expr("Index", visit_expr(node.obj), visit_expr(node.idx))
    end
    Expr[TExpr.Property] = function(node)
        return expr("Property", visit_expr(node.obj), node.prop)
    end
    Expr[TExpr.Invoke] = function(node)
        return expr("Invoke", visit_expr(node.obj), node.prop, visit_exprs(node.args))
    end
    Expr[TExpr.Call] = function(node)
        return expr("Call", visit_expr(node.func), visit_exprs(node.args))
    end
    Expr[TExpr.Unary] = function(node)
        return expr("Unary", node.op, visit_expr(node.left))
    end
    Expr[TExpr.Binary] = function(node)
        return expr("Binary", node.op, visit_expr(node.left), visit_expr(node.right))
    end
    Stmt[TStmt.Expr] = function(node)
        return stmt("ExprStatement", visit_expr(node.expr))
    end
    Stmt[TStmt.Local] = function(node)
        return stmt("Local", visit_exprs(node.vars), visit_exprs(node.exprs))
    end
    Stmt[TStmt.Assign] = function(node)
        return stmt("Assign", visit_exprs(node.lefts), visit_exprs(node.rights))
    end
    Stmt[TStmt.Do] = function(node)
        return block(stmt("Do"), node.body)
    end
    Stmt[TStmt.If] = function(node)
        local blocks = {}
        blocks[1] = block(stmt("If", visit_expr(node.tests[1])), node.thenss[1])
        for i = 2, #node.tests, 1 do
            blocks[i] = block(indentation() .. "elseif " .. visit_expr(node.tests[i]), node.thenss[i])
        end
        if node.elses then
            blocks[#blocks + 1] = block(indentation() .. "else", node.elses)
        end
        return table.concat(blocks)
    end
    Stmt[TStmt.Forin] = function(node)
        return block(stmt("Forin", visit_exprs(node.vars), visit_exprs(node.exprs)), node.body)
    end
    Stmt[TStmt.Fornum] = function(node)
        return block(stmt("Fornum", visit_expr(node.var), visit_expr(node.first), visit_expr(node.last), node.step and visit_expr(node.step) or ""), node.body)
    end
    Stmt[TStmt.While] = function(node)
        return block(stmt("While", visit_expr(node.test)), node.body)
    end
    Stmt[TStmt.Repeat] = function(node)
        return block(stmt("Repeat until", visit_expr(node.test)), node.body)
    end
    Stmt[TStmt.Return] = function(node)
        return stmt("Return", visit_exprs(node.exprs))
    end
    Stmt[TStmt.Break] = function()
        return stmt("Break")
    end
    Stmt[TStmt.Goto] = function(node)
        return stmt("Goto", node.name)
    end
    Stmt[TStmt.Label] = function(node)
        return stmt("Label", node.name)
    end
    return visit_stmts(stmts)
end
local same
same = function(a, b)
    if a and b and a.tag == b.tag then
        local last = 1
        if #a ~= #b then
            return false
        end
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
                if "table" == type(v) then
                    if not same(v, b[k]) then
                        return false
                    end
                elseif b[k] ~= v then
                    return false
                end
            end
        end
        for k, v in pairs(b) do
            if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
                if "table" == type(v) then
                    if not same(v, a[k]) then
                        return false
                    end
                elseif a[k] ~= v then
                    return false
                end
            end
        end
        return true
    end
    return false
end
return {Stmt = Statement, Expr = Expression, bracket = bracket, same = same, dump = dump}