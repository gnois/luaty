--
-- Generated from transform.lt
--
local ast = require("lua.ast")
local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local id = ast.Expr.id
local setmt = function(tbl, mt, node)
    return ast.Expr.call(id("setmetatable", node), {tbl, mt}, node)
end
local str = function(txt, node)
    return ast.Expr.string(txt, false, node)
end
local construct = function(node)
    local vks = {}
    local mt = ast.Expr.table({{str(node.name.name, node), str("__metatable", node)}}, node)
    for i, v in ipairs(node.variants) do
        local key = str(v.ctor.name, v.ctor)
        local params = {{str(v.ctor.name, v.ctor), str("id", v.ctor)}}
        for n, p in ipairs(v.params) do
            params[n + 1] = {p}
        end
        local tbl = ast.Expr.table(params, v.ctor)
        local val = ast.Expr["function"](v.params, {}, {}, {ast.Stmt["return"]({setmt(tbl, id("mt", node), node)}, v.ctor)}, node)
        vks[i] = {val, key}
    end
    local tbl = ast.Expr.table(vks, node)
    local idvar = id("var", node)
    local test = ast.Expr.binary("and", ast.Expr.binary("==", str("table", node), ast.Expr.call(id("type", node), {idvar}, node), node), ast.Expr.binary("==", str(node.name.name, node), ast.Expr.call(id("getmetatable", node), {idvar}, node), node), node)
    local testfn = ast.Expr["function"]({id("_", node), idvar}, {}, {}, {ast.Stmt["if"]({test}, {{ast.Stmt["return"]({ast.Expr.index(idvar, str("id", node), node)}, node)}}, nil, node)}, node)
    local callable = ast.Expr.table({{testfn, str("__call", node)}}, node)
    local lambda = ast.Expr["function"]({id("mt", node)}, {}, {}, {ast.Stmt["return"]({setmt(tbl, callable, node)}, node)}, node)
    return ast.Stmt["local"]({node.name}, {}, {ast.Expr.call(lambda, {mt}, node)}, node)
end
local destruct = function(node)
    local vks = {}
    for i, v in ipairs(node.variants) do
        local key = str(v.ctor and v.ctor.name or "_", v.ctor or node)
        local val = ast.Expr["function"](v.params or {}, {}, {}, v.body, v.ctor or node)
        vks[i] = {val, key}
    end
    local tbl = ast.Expr.table(vks, node)
    local idx = ast.Expr.binary("or", ast.Expr.call(node.name, {node.arg}, node), str("_", node), node)
    local index = ast.Expr.index(tbl, idx, node)
    return ast.Stmt["do"]({ast.Stmt.expression(ast.Expr.call(index, {ast.Expr.call(id("unpack", node), {node.arg}, node)}, node), node)}, node)
end
return function(stmts)
    local Stmt = {}
    local Expr = {}
    local visit_stmts = function(nodes)
        local list = {}
        for i, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            list[i] = rule and rule(node) or node
        end
        return list
    end
    local visit_expr = function(node)
        local rule = Expr[node.tag]
        return rule and rule(node) or node
    end
    local visit_exprs = function(nodes)
        local list = {}
        for i, node in ipairs(nodes) do
            list[i] = visit_expr(node)
        end
        return list
    end
    Expr[TExpr.Id] = function(node)
        if node.name == "@" then
            node.name = "self"
        end
        return node
    end
    Expr[TExpr.Function] = function(node)
        node.params = visit_exprs(node.params)
        node.body = visit_stmts(node.body)
        return node
    end
    Expr[TExpr.Table] = function(node)
        local valkeys = {}
        for i, kv in ipairs(node.valkeys) do
            valkeys[i] = {}
            valkeys[i][1] = visit_expr(kv[1])
            if kv[2] then
                valkeys[i][2] = visit_expr(kv[2])
            end
        end
        node.valkeys = valkeys
        return node
    end
    Expr[TExpr.Index] = function(node)
        node.obj = visit_expr(node.obj)
        node.idx = visit_expr(node.idx)
        return node
    end
    Expr[TExpr.Property] = function(node)
        node.obj = visit_expr(node.obj)
        return node
    end
    Expr[TExpr.Call] = function(node)
        node.func = visit_expr(node.func)
        local arg1 = node.args[1]
        if arg1 and arg1.name == "@" then
            local func = node.func
            if not func.bracketed then
                if func.tag == TExpr.Property then
                    table.remove(node.args, 1)
                    return ast.Expr.invoke(func.obj, func.prop, node.args, node)
                elseif func.tag == TExpr.Index then
                    local obj = id("_self_", node)
                    node.args[1] = obj
                    local body = {ast.Stmt["local"]({obj}, {}, {func.obj}, node), ast.Stmt["return"]({ast.Expr.call(ast.Expr.index(obj, func.idx, node), node.args, node)}, node)}
                    local lambda = ast.Expr["function"]({}, {}, {}, body, node)
                    return ast.Expr.call(lambda, {}, node)
                end
            end
        end
        node.args = visit_exprs(node.args)
        return node
    end
    Expr[TExpr.Unary] = function(node)
        node.left = visit_expr(node.left)
        return node
    end
    Expr[TExpr.Binary] = function(node)
        node.left = visit_expr(node.left)
        node.right = visit_expr(node.right)
        return node
    end
    Stmt[TStmt.Expr] = function(node)
        node.expr = visit_expr(node.expr)
        return node
    end
    Stmt[TStmt.Local] = function(node)
        node.vars = visit_exprs(node.vars)
        node.exprs = visit_exprs(node.exprs)
        return node
    end
    Stmt[TStmt.Data] = function(node)
        if node.variants[#node.variants].ctor then
            return construct(node)
        end
        return destruct(node)
    end
    Stmt[TStmt.Assign] = function(node)
        node.lefts = visit_exprs(node.lefts)
        node.rights = visit_exprs(node.rights)
        return node
    end
    Stmt[TStmt.Do] = function(node)
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.If] = function(node)
        for i = 1, #node.tests do
            node.tests[i] = visit_expr(node.tests[i])
            node.thenss[i] = visit_stmts(node.thenss[i])
        end
        if node.elses then
            node.elses = visit_stmts(node.elses)
        end
        return node
    end
    Stmt[TStmt.Forin] = function(node)
        node.exprs = visit_exprs(node.exprs)
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.Fornum] = function(node)
        node.first = visit_expr(node.first)
        node.last = visit_expr(node.last)
        if node.step then
            node.step = visit_expr(node.step)
        end
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.While] = function(node)
        node.test = visit_expr(node.test)
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.Repeat] = function(node)
        node.body = visit_stmts(node.body)
        node.test = visit_expr(node.test)
        return node
    end
    Stmt[TStmt.Return] = function(node)
        node.exprs = visit_exprs(node.exprs)
        return node
    end
    return visit_stmts(stmts)
end
