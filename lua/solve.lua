--
-- Generated from solve.lt
--
local ty = require("lua.type")
local Tag = require("lua.tag")
local TType = Tag.Type
local subs = {}
local Subst = {}
local subst = function(node, tvar, texp)
    assert(tvar.tag == TType.New)
    local rule = Subst[node.tag]
    if rule then
        return rule(node, tvar, texp)
    end
    return node
end
Subst[TType.New] = function(node, tvar, texp)
    if node.id == tvar.id then
        return texp
    end
    return node
end
Subst[TType.Ref] = function(node, tvar, texp)
    if node.ins then
        local ins, outs = {}, {}
        for i, p in ipairs(node.ins.types) do
            ins[i] = subst(p, tvar, texp)
        end
        for i, r in ipairs(node.outs.types) do
            outs[i] = subst(r, tvar, texp)
        end
        return ty.func(ty.tuple(ins), ty.tuple(outs))
    end
    local tytys = {}
    for i, tk in ipairs(node.tytys) do
        tytys[i] = {subst(tk[1], tvar, texp), tk[2] and subst(tk[2], tvar, texp)}
    end
    return ty.tbl(tytys)
end
Subst[TType.Or] = function(node, tvar, texp)
    local left = subst(node.left, tvar, texp)
    local right = subst(node.right, tvar, texp)
    return ty["or"](left, right)
end
Subst[TType.And] = function(node, tvar, texp)
    local left = subst(node.left, tvar, texp)
    local right = subst(node.right, tvar, texp)
    return ty["and"](left, right)
end
local Apply = {}
local apply = function(y)
    local rule = Apply[y.tag]
    if rule then
        return rule(y)
    end
    return y
end
Apply[TType.New] = function(node)
    return subs[node.id] or node
end
Apply[TType.Ref] = function(node)
    if node.ins then
        local ins, outs = {}, {}
        for i, p in ipairs(node.ins.types) do
            ins[i] = apply(p)
        end
        for i, r in ipairs(node.outs.types) do
            outs[i] = apply(r)
        end
        return ty.func(ty.tuple(ins), ty.tuple(outs))
    end
    local tytys = {}
    for i, tk in ipairs(node.tytys) do
        tytys[i] = {apply(tk[1]), tk[2] and apply(tk[2])}
    end
    return ty.tbl(tytys)
end
Apply[TType.Or] = function(node)
    local left = apply(node.left)
    local right = apply(node.right)
    return ty["or"](left, right)
end
Apply[TType.And] = function(node)
    local left = apply(node.left)
    local right = apply(node.right)
    return ty["and"](left, right)
end
local Occur = {}
local occurs = function(x, y)
    local rule = Occur[x.tag]
    if rule then
        return rule(x, y)
    end
    return false
end
Occur[TType.Ref] = function(node, y)
    if node.ins then
        for _, p in ipairs(node.ins.types) do
            if occurs(p, y) then
                return true
            end
        end
        for _, r in ipairs(node.outs.types) do
            if occurs(r, y) then
                return true
            end
        end
        return false
    end
    for _, tk in ipairs(node.tytys) do
        if occurs(tk[1], y) or tk[2] and occurs(tk[2], y) then
            return true
        end
    end
    return false
end
Occur[TType.Or] = function(node, y)
    return occurs(node.left, y) or occurs(node.right, y)
end
Occur[TType.And] = function(node, y)
    return occurs(node.left, y) or occurs(node.right, y)
end
local extend = function(tvar, texp)
    assert(tvar.tag == TType.New)
    if occurs(tvar, texp) then
        return false, "cannot infer recursive type"
    end
    for id, t in ipairs(subs) do
        subs[id] = subst(t, tvar, texp)
    end
    subs[tvar.id] = texp
    return true
end
local unify
local unify_func = function(x, y)
    local xs, ys = x.ins.types, y.ins.types
    local i, n = 0, #xs
    local ok, err
    while i < n do
        i = i + 1
        if ys[i] then
            ok, err = unify(xs[i], ys[i])
            if not ok then
                return false, err
            end
        else
            return false, "expecting " .. n .. " arguments but only got " .. i - 1
        end
    end
    n = #ys
    if i < n then
        if i < 1 or not xs[i].varargs then
            return false, "expecting only " .. i .. " arguments but got " .. n
        end
    end
    return true
end
local unify_tbl = function(x, y)
    return true
end
unify = function(x, y)
    x = apply(x)
    y = apply(y)
    if x.tag == TType.New then
        return extend(x, y)
    end
    if y.tag == TType.New then
        return extend(y, x)
    end
    if x.tag == TType.Any and y.tag ~= TType.Nil then
        return true
    end
    if y.tag == TType.Any and x.tag ~= TType.Nil then
        return true
    end
    if x.tag == TType.Or then
        if unify(x.left, y) or unify(x.right, y) then
            return true
        end
    end
    if y.tag == TType.Or then
        if unify(x, y.left) or unify(x, y.right) then
            return true
        end
    end
    if x.tag == TType.And then
        if unify(x.left, y) and unify(x.right, y) then
            return true
        end
    end
    if y.tag == TType.And then
        if unify(x, y.right) and unify(x, y.right) then
            return true
        end
    end
    if x.tag == y.tag then
        if x.tag == TType.Nil then
            return true
        end
        if x.tag == TType.Val then
            if x.type == y.type then
                return true
            end
        end
        if x.tag == TType.Ref then
            if x.ins and y.ins then
                return unify_func(x, y)
            end
            if x.tytys and y.tytys then
                return unify_tbl(x, y)
            end
        end
    end
    return false, "expecting " .. ty.tostr(x) .. " instead of " .. ty.tostr(y)
end
return {apply = apply, unify = unify}
