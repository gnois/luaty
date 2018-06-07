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
    , union = function(variants, test, arg, ls)
        return make(TExpr.Union, {variants = variants, test = test, arg = arg}, ls)
    end
    , unary = function(op, right, ls)
        return make(TExpr.Unary, {op = op, right = right}, ls)
    end
    , binary = function(op, left, right, ls)
        return make(TExpr.Binary, {op = op, left = left, right = right}, ls)
    end
}
local id = 0
local Type = {
    new = function(ls)
        id = id + 1
        return make(TType.New, {id = id}, ls)
    end
    , any = function(ls)
        return make(TType.Any, {}, ls)
    end
    , ["nil"] = function(ls)
        return make(TType.Nil, {}, ls)
    end
    , num = function(ls)
        return make(TType.Val, {type = "num"}, ls)
    end
    , str = function(ls)
        return make(TType.Val, {type = "str"}, ls)
    end
    , bool = function(ls)
        return make(TType.Val, {type = "bool"}, ls)
    end
    , tuple = function(types, ls)
        return make(TType.Tuple, {types = types}, ls)
    end
    , func = function(params, returns, ls)
        return make(TType.Ref, {params = params, returns = returns}, ls)
    end
    , tbl = function(tytys, ls)
        return make(TType.Ref, {tytys = tytys}, ls)
    end
    , ["or"] = function(left, right, ls)
        return make(TType.Or, {left = left, right = right}, ls)
    end
    , ["and"] = function(left, right, ls)
        return make(TType.And, {left = left, right = right}, ls)
    end
    , index = function(obj, prop, ls)
        return make(TType.Index, {obj = obj, prop = prop}, ls)
    end
    , typeof = function(name, ls)
        return make(TType.Typeof, {name = name}, ls)
    end
}
local bracket = function(node)
    assert(TExpr[node.tag] or TType[node.tag])
    node.bracketed = true
    return node
end
local varargs = function(t)
    assert(TType[t.tag])
    if t.varargs then
        return false
    end
    t.varargs = true
    return true
end
local nils = function(t)
    assert(TType[t.tag])
    if t["nil"] then
        return false
    end
    t["nil"] = true
    return true
end
local Str = {}
local tostr
local tolst = function(ls)
    local out = {}
    for i, p in ipairs(ls) do
        out[i] = tostr(p)
    end
    return table.concat(out, ",")
end
tostr = function(t)
    assert(TType[t.tag])
    local rule = Str[t.tag]
    return rule(t)
end
Str[TType.New] = function(t)
    return "T" .. t.id
end
Str[TType.Any] = function(t)
    return "any"
end
Str[TType.Nil] = function(t)
    return "nil"
end
Str[TType.Val] = function(t)
    return t.type
end
Str[TType.Ref] = function(t)
    if t.params then
        local out = {"[", tolst(t.params), ":", tolst(t.returns), "]"}
        return table.concat(out)
    end
    if t.tytys then
        local out, o = {}, 1
        local val
        for _, ty in ipairs(t.tytys) do
            local vty = ty[1]
            local kty = ty[2]
            if kty then
                if "string" == type(kty) then
                    out[o] = kty .. ": " .. tostr(vty)
                else
                    out[o] = tostr(kty) .. ": " .. tostr(vty)
                end
                o = o + 1
            else
                val = tostr(vty)
            end
        end
        local ls = table.concat(out, ", ")
        if val then
            ls = val .. ", " .. ls
        end
        return "{" .. ls .. "}"
    end
end
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
return {
    Stmt = Statement
    , Expr = Expression
    , Type = Type
    , bracket = bracket
    , varargs = varargs
    , nils = nils
    , same = same
    , tostr = tostr
}
