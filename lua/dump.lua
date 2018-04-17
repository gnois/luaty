--
-- Generated from dump.lt
--

local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
return function(stmts)
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
        for i, vk in ipairs(node.valkeys) do
            val = visit_expr(vk[1])
            if vk[2] then
                key = visit_expr(vk[2])
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