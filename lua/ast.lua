--
-- Generated from ast.lt
--
local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
local make = function(tag, node, ls)
    assert("table" == type(node))
    assert("number" == type(ls.line))
    assert("number" == type(ls.col))
    node.tag = tag
    node.line = ls.line
    node.col = ls.col
    return node
end
local Statement = {
    expression = function(expr, ls)
        return make(TStmt.Expr, {expr = expr}, ls)
    end
    , assign = function(lhs, rhs, ls)
        return make(TStmt.Assign, {lefts = lhs, rights = rhs}, ls)
    end
    , ["local"] = function(vars, types, exprs, ls)
        return make(TStmt.Local, {vars = vars, types = types, exprs = exprs}, ls)
    end
    , ["do"] = function(body, ls)
        return make(TStmt.Do, {body = body}, ls)
    end
    , ["if"] = function(tests, thenss, elses, ls)
        return make(TStmt.If, {tests = tests, thenss = thenss, elses = elses}, ls)
    end
    , forin = function(vars, types, exprs, body, ls)
        return make(TStmt.Forin, {vars = vars, types = types, exprs = exprs, body = body}, ls)
    end
    , fornum = function(var, first, last, step, body, ls)
        return make(TStmt.Fornum, {var = var, first = first, last = last, step = step, body = body}, ls)
    end
    , ["while"] = function(test, body, ls)
        return make(TStmt.While, {test = test, body = body}, ls)
    end
    , ["repeat"] = function(test, body, ls)
        return make(TStmt.Repeat, {test = test, body = body}, ls)
    end
    , ["return"] = function(exprs, ls)
        return make(TStmt.Return, {exprs = exprs}, ls)
    end
    , ["break"] = function(ls)
        return make(TStmt.Break, {}, ls)
    end
    , ["goto"] = function(name, ls)
        return make(TStmt.Goto, {name = name}, ls)
    end
    , label = function(name, ls)
        return make(TStmt.Label, {name = name}, ls)
    end
}
local Expression = {
    ["nil"] = function(ls)
        return make(TExpr.Nil, {}, ls)
    end
    , vararg = function(ls)
        return make(TExpr.Vararg, {}, ls)
    end
    , id = function(name, ls)
        return make(TExpr.Id, {name = name}, ls)
    end
    , bool = function(val, ls)
        return make(TExpr.Bool, {value = val}, ls)
    end
    , number = function(val, ls)
        return make(TExpr.Number, {value = val}, ls)
    end
    , string = function(val, long, ls)
        return make(TExpr.String, {value = val, long = long}, ls)
    end
    , ["function"] = function(params, types, retypes, body, ls)
        return make(TExpr.Function, {params = params, types = types, retypes = retypes, body = body}, ls)
    end
    , table = function(valkeys, ls)
        return make(TExpr.Table, {valkeys = valkeys}, ls)
    end
    , index = function(obj, index, ls)
        return make(TExpr.Index, {obj = obj, idx = index}, ls)
    end
    , property = function(obj, prop, ls)
        return make(TExpr.Property, {obj = obj, prop = prop}, ls)
    end
    , invoke = function(obj, prop, args, ls)
        return make(TExpr.Invoke, {obj = obj, prop = prop, args = args}, ls)
    end
    , call = function(func, args, ls)
        return make(TExpr.Call, {func = func, args = args}, ls)
    end
    , unary = function(op, left, ls)
        return make(TExpr.Unary, {op = op, left = left}, ls)
    end
    , binary = function(op, left, right, ls)
        return make(TExpr.Binary, {op = op, left = left, right = right}, ls)
    end
}
local build = function(ty, obj, node)
    obj.type = ty
    obj.node = node
    return obj
end
local Type = {
    any = function(node)
        return build(TType.Any, {}, node)
    end
    , num = function(node)
        return build(TType.Num, {}, node)
    end
    , str = function(node)
        return build(TType.Str, {}, node)
    end
    , bool = function(node)
        return build(TType.Bool, {}, node)
    end
    , func = function(params, returns, node)
        return build(TType.Func, {params = params, returns = returns}, node)
    end
    , tbl = function(valkeys, node)
        return build(TType.Tbl, {valkeys = valkeys}, node)
    end
    , ["or"] = function(left, right, node)
        return build(TType.Or, {left = left, right = right}, node)
    end
    , ["and"] = function(left, right, node)
        return build(TType.And, {left = left, right = right}, node)
    end
    , index = function(obj, prop, node)
        return build(TType.Index, {obj = obj, prop = prop}, node)
    end
    , custom = function(name, node)
        return build(TType.Custom, {name = name}, node)
    end
}
local bracket = function(node)
    assert(TExpr[node.tag] or TType[node.type])
    node.bracketed = true
    return node
end
local nils = function(node)
    assert(TType[node.type])
    node["nil"] = true
    return node
end
local varargs = function(node)
    assert(TType[node.type])
    node.varargs = true
    return node
end
local nillable = function(node)
    assert(TType[node.type])
    return node["nil"]
end
return {Stmt = Statement, Expr = Expression, Type = Type, bracket = bracket, nils = nils, varargs = varargs, nillable = nillable}
