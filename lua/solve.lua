--
-- Generated from solve.lt
--
local ty = require("lua.type")
local Tag = require("lua.tag")
local TType = Tag.Type
return function()
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
            for i, p in ipairs(node.ins) do
                ins[i] = subst(p, tvar, texp)
            end
            for i, r in ipairs(node.outs) do
                outs[i] = subst(r, tvar, texp)
            end
            return ty.func(ty.tuple(ins), ty.tuple(outs))
        end
        local tytys = {}
        for i, tk in ipairs(node) do
            tytys[i] = {subst(tk[1], tvar, texp), tk[2] and subst(tk[2], tvar, texp)}
        end
        return ty.tbl(tytys)
    end
    Subst[TType.Or] = function(node, tvar, texp)
        local list = {}
        for i, t in ipairs(node) do
            list[i] = subst(t, tvar, texp)
        end
        return ty["or"](unpack(list))
    end
    local Apply = {}
    local apply = function(node)
        local rule = Apply[node.tag]
        if rule then
            return rule(node)
        end
        return node
    end
    Apply[TType.New] = function(node)
        return subs[node.id] or node
    end
    Apply[TType.Ref] = function(node)
        if node.ins then
            local ins, outs = {}, {}
            for i, p in ipairs(node.ins) do
                ins[i] = apply(p)
            end
            for i, r in ipairs(node.outs) do
                outs[i] = apply(r)
            end
            return ty.func(ty.tuple(ins), ty.tuple(outs))
        end
        local tytys = {}
        for i, tk in ipairs(node) do
            tytys[i] = {apply(tk[1]), tk[2] and apply(tk[2])}
        end
        return ty.tbl(tytys)
    end
    Apply[TType.Or] = function(node)
        local list = {}
        for i, t in ipairs(node) do
            list[i] = apply(t)
        end
        return ty["or"](unpack(list))
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
            for _, p in ipairs(node.ins) do
                if occurs(p, y) then
                    return true
                end
            end
            for _, r in ipairs(node.outs) do
                if occurs(r, y) then
                    return true
                end
            end
            return false
        end
        for _, tk in ipairs(node) do
            if occurs(tk[1], y) or tk[2] and occurs(tk[2], y) then
                return true
            end
        end
        return false
    end
    Occur[TType.Or] = function(node, y)
        for _, t in ipairs(node) do
            if occurs(t, y) then
                return true
            end
        end
        return false
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
        local xs, ys = x.ins, y.ins
        local i, n = 0, #xs
        local ok, err
        while i < n do
            i = i + 1
            if ys[i] then
                ok, err = unify(xs[i], ys[i])
                if not ok then
                    return false, "parameter " .. i .. " " .. err
                end
            else
                if not xs[i].varargs then
                    return false, "expects " .. n .. " arguments but only got " .. i - 1
                end
                return true
            end
        end
        n = #ys
        if i < n then
            if i < 1 or not xs[i].varargs then
                return false, "expects only " .. i .. " arguments but got " .. n
            end
        end
        return true
    end
    local unify_tbl = function(x, y)
        local key_str = function(k)
            return "string" == type(k) and k or ty.tostr(k)
        end
        local keys = {}
        for __, tty in ipairs(y) do
            if tty[2] then
                keys[tty[2]] = tty[1]
            end
        end
        for _, ttx in ipairs(x) do
            if ttx[2] then
                local vy = keys[ttx[2]]
                if vy then
                    local ok, err = unify(ttx[1], vy)
                    if not ok then
                        return false, err .. " for key `" .. key_str(ttx[2]) .. "`"
                    end
                else
                    return false, "expects key `" .. key_str(ttx[2]) .. "`"
                end
            end
        end
        return true
    end
    unify = function(x, y)
        if x == y then
            return true
        end
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
            for _, t in ipairs(x) do
                if unify(t, y) then
                    return true
                end
            end
        end
        if y.tag == TType.Or then
            for _, t in ipairs(y) do
                if unify(x, t) then
                    return true
                end
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
                return unify_tbl(x, y)
            end
        end
        return false, "expects " .. ty.tostr(x) .. " instead of " .. ty.tostr(y)
    end
    return {apply = apply, unify = unify}
end
