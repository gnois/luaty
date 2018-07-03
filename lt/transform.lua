--
-- Generated from transform.lt
--
local ast = require("lt.ast")
local Tag = require("lt.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local id = ast.Expr.id
local setmt = function(tbl, mt, node)
    return ast.Expr.call(id("setmetatable", node), {tbl, mt}, node)
end
local str = function(txt, node)
    return ast.Expr.string(txt, false, node)
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
    local construct = function(node)
        local uniq, u = {"."}, 1
        local _id = id("_id", node)
        local _nm = id("_nm", node)
        local _mk = id("_mk", node)
        local mt = ast.Expr.table({{_id, str("__metatable", node)}}, node)
        local maker = ast.Stmt["local"]({_mk}, {}, {ast.Expr["function"]({_nm, ast.Expr.vararg(node)}, nil, nil, {ast.Stmt["return"]({setmt(ast.Expr.table({{_nm, str("!", node)}, {ast.Expr.vararg(node)}}, node), mt, node)}, node)}, node)}, node)
        local vks = {}
        for i, v in ipairs(node.variants) do
            u = u + 1
            uniq[u] = v.ctor.name
            local key = str(v.ctor.name, v.ctor)
            local params = {key}
            for n, p in ipairs(v.params) do
                u = u + 1
                uniq[u] = p.name or "."
                params[n + 1] = p
            end
            local val = ast.Expr["function"](v.params, nil, nil, {ast.Stmt["return"]({ast.Expr.call(_mk, params, v.ctor)}, v.ctor)}, node)
            vks[i] = {val, key}
        end
        local tbl = ast.Expr.table(vks, node)
        local unique_str = str(table.concat(uniq), node)
        local _v = id("_v", node)
        local test = ast.Expr.binary("and", ast.Expr.binary("==", str("table", node), ast.Expr.call(id("type", node), {_v}, node), node), ast.Expr.binary("==", _id, ast.Expr.call(id("getmetatable", node), {_v}, node), node), node)
        local testfn = ast.Expr["function"]({id("_t", node), _v}, nil, nil, {ast.Stmt["if"]({test}, {{ast.Stmt["return"]({ast.Expr.index(_v, str("!", node), node), ast.Expr.call(id("unpack", node), {_v}, node)}, node)}}, nil, node)}, node)
        local callable = ast.Expr.table({{testfn, str("__call", node)}}, node)
        local lambda = ast.Expr["function"]({_id}, nil, nil, {maker, ast.Stmt["return"]({setmt(tbl, callable, node)}, node)}, node)
        return ast.Expr.call(lambda, {unique_str}, node)
    end
    local destruct = function(node)
        local ret_call = function(params, body, args, loc)
            return ast.Stmt["return"]({ast.Expr.call(ast.Expr["function"](params, nil, nil, body, loc), args, loc)}, loc)
        end
        local tests, blocks, n = {}, {}, 0
        local els
        local _nm = id("_nm", node)
        for _, v in ipairs(node.variants) do
            local all = ast.Expr.vararg(v.ctor)
            local handler = visit_stmts(v.body)
            if #v.params > 0 then
                handler = {ret_call(v.params, handler, {all}, v.ctor)}
            end
            if v.ctor.name == "*" then
                els = handler
            else
                n = n + 1
                blocks[n] = handler
                tests[n] = ast.Expr.binary("==", str(v.ctor.name, v.ctor), _nm, v.ctor)
            end
        end
        local conds
        if n > 0 then
            conds = {ast.Stmt["if"](tests, blocks, els, node)}
        elseif els then
            conds = els
        end
        local lambda = ast.Expr["function"]({_nm, ast.Expr.vararg(node)}, nil, nil, conds, node)
        local test = visit_expr(node.test)
        local arg = visit_expr(node.arg)
        return ast.Expr.call(lambda, {ast.Expr.call(test, {arg}, node)}, node)
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
    Expr[TExpr.Field] = function(node)
        node.obj = visit_expr(node.obj)
        return node
    end
    Expr[TExpr.Call] = function(node)
        node.func = visit_expr(node.func)
        local arg1 = node.args[1]
        if arg1 and arg1.name == "@" then
            local func = node.func
            if not func.bracketed then
                if func.tag == TExpr.Field then
                    table.remove(node.args, 1)
                    return ast.Expr.invoke(func.obj, func.field, node.args, node)
                end
                if func.tag == TExpr.Index then
                    local obj = id("_self_", node)
                    node.args[1] = obj
                    local body = {ast.Stmt["local"]({obj}, {}, {func.obj}, node), ast.Stmt["return"]({ast.Expr.call(ast.Expr.index(obj, func.idx, node), node.args, node)}, node)}
                    local lambda = ast.Expr["function"]({}, nil, nil, body, node)
                    return ast.Expr.call(lambda, {}, node)
                end
            end
        end
        node.args = visit_exprs(node.args)
        return node
    end
    Expr[TExpr.Union] = function(node)
        if node.test and node.arg then
            return destruct(node)
        end
        return construct(node)
    end
    Expr[TExpr.Unary] = function(node)
        node.right = visit_expr(node.right)
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
