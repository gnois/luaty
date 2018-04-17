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
local Expression = {["nil"] = function(ls)
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
end, table = function(valkeys, ls)
    return make(TExpr.Table, {valkeys = valkeys}, ls)
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
local Type = {any = function()
    return make(TType.Any, {})
end, num = function()
    return make(TType.Num, {})
end, str = function()
    return make(TType.Str, {})
end, bool = function()
    return make(TType.Bool, {})
end, func = function(params, returns)
    return make(TType.Func, {params = params, returns = returns})
end, tbl = function(valkeys)
    return make(TType.Tbl, {valkeys = valkeys})
end, ["or"] = function(left, right)
    return make(TType.Or, {left = left, right = right})
end, ["and"] = function(left, right)
    return make(TType.And, {left = left, right = right})
end, ["not"] = function(ty)
    return make(TType.Not, {ty})
end, index = function(obj, prop)
    return make(TType.Index, {obj = obj, prop = prop})
end, keyed = function(name)
    return make(TType.Keyed, {name = name})
end, custom = function(name)
    return make(TType.Custom, {name = name})
end}
local bracket = function(node)
    node.bracketed = true
    return node
end
local nils = function(node)
    node["nil"] = true
    return node
end
local varargs = function(node)
    node.varargs = true
    return node
end
local nillable = function(node)
    return node["nil"]
end
return {Stmt = Statement, Expr = Expression, Type = Type, bracket = bracket, nils = nils, varargs = varargs, nillable = nillable}