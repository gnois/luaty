--
-- Generated from ast.lt
--

local Tag = require("lua.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local make = function(tag, node, line)
    assert("table" == type(node))
    node.tag = tag
    node.line = line
    return node
end
local Stmt = {expression = function(expr, line)
    return make(TStmt.Expr, {expression = expr}, line)
end, declare = function(lhs, rhs, line)
    return make(TStmt.Local, {names = lhs, expressions = rhs}, line)
end, assign = function(lhs, rhs, line)
    return make(TStmt.Assign, {left = lhs, right = rhs}, line)
end, ["do"] = function(body, line)
    return make(TStmt.Do, {body = body}, line)
end, ["if"] = function(tests, conds, els, line)
    return make(TStmt.If, {tests = tests, conds = conds, els = els}, line)
end, forin = function(vars, exprs, body, line)
    return make(TStmt.Forin, {vars = vars, explist = exprs, body = body}, line)
end, fornum = function(var, first, last, step, body, line)
    return make(TStmt.Fornum, {var = var, first = first, last = last, step = step, body = body}, line)
end, ["while"] = function(test, body, line)
    return make(TStmt.While, {test = test, body = body}, line)
end, ["repeat"] = function(test, body, line)
    return make(TStmt.Repeat, {test = test, body = body}, line)
end, ["return"] = function(exps, line)
    return make(TStmt.Return, {arguments = exps}, line)
end, ["break"] = function(line)
    return make(TStmt.Break, {}, line)
end, ["goto"] = function(label, line)
    return make(TStmt.Goto, {label = label}, line)
end, label = function(name, line)
    return make(TStmt.Label, {name = name}, line)
end}
local Expr = {null = function(line)
    return make(TExpr.Nil, {}, line)
end, vararg = function(line)
    return make(TExpr.Vararg, {}, line)
end, bool = function(val, line)
    return make(TExpr.Bool, {value = val}, line)
end, number = function(val, line)
    return make(TExpr.Number, {value = val}, line)
end, string = function(val, long, line)
    return make(TExpr.String, {value = val, long = long}, line)
end, ["function"] = function(params, body, vararg, line)
    return make(TExpr.Function, {body = body, params = params, vararg = vararg}, line)
end, table = function(keyvals, line)
    return make(TExpr.Table, {keyvals = keyvals}, line)
end, index = function(obj, index, line)
    return make(TExpr.Index, {object = obj, index = index}, line)
end, property = function(obj, prop, line)
    return make(TExpr.Property, {object = obj, property = prop}, line)
end, call = function(func, args, line)
    return make(TExpr.Call, {func = func, arguments = args}, line)
end, invoke = function(obj, method, args, line)
    return make(TExpr.Invoke, {object = obj, method = method, arguments = args}, line)
end, unary = function(op, v, line)
    return make(TExpr.Unary, {operator = op, argument = v}, line)
end, binary = function(op, left, right, line)
    return make(TExpr.Binary, {operator = op, left = left, right = right}, line)
end, id = function(name, line)
    return make(TExpr.Id, {name = name}, line)
end}
local bracket = function(node)
    assert("table" == type(node))
    node.bracketed = true
    return node
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
return {Stmt = Stmt, Expr = Expr, bracket = bracket, same = same}