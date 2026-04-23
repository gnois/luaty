--
-- Generated from solve.lt
--
local ty = require("lt.type")
local Tag = require("lt.tag")
local TType = Tag.Type
return function()
    local subs = {}
    local lower_bounds = {}
    local upper_bounds = {}
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
    Subst[TType.Tuple] = function(node, tvar, texp)
        for i = 1, #node do
            node[i] = subst(node[i], tvar, texp)
        end
        return node
    end
    Subst[TType.Func] = function(node, tvar, texp)
        node.ins = subst(node.ins, tvar, texp)
        node.outs = subst(node.outs, tvar, texp)
        return node
    end
    Subst[TType.Tbl] = function(node, tvar, texp)
        for i = 1, #node do
            node[i] = {subst(node[i][1], tvar, texp), node[i][2] and subst(node[i][2], tvar, texp)}
        end
        return node
    end
    Subst[TType.Or] = function(node, tvar, texp)
        for i = 1, #node do
            node[i] = subst(node[i], tvar, texp)
        end
        return node
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
    Apply[TType.Tuple] = function(node)
        for i = 1, #node do
            node[i] = apply(node[i])
        end
        return node
    end
    Apply[TType.Func] = function(node)
        node.ins = apply(node.ins)
        node.outs = apply(node.outs)
        return node
    end
    Apply[TType.Tbl] = function(node)
        for i = 1, #node do
            node[i] = {apply(node[i][1]), node[i][2] and apply(node[i][2])}
        end
        return node
    end
    Apply[TType.Or] = function(node)
        for i = 1, #node do
            node[i] = apply(node[i])
        end
        return node
    end
    local Occur = {}
    local occurs = function(x, y)
        local rule = Occur[y.tag]
        if rule then
            return rule(x, y)
        end
        return false
    end
    Occur[TType.New] = function(x, node)
        return x.id == node.id
    end
    Occur[TType.Tuple] = function(x, node)
        for _, p in ipairs(node) do
            if occurs(x, p) then
                return true
            end
        end
        return false
    end
    Occur[TType.Func] = function(x, node)
        return occurs(x, node.ins) or occurs(x, node.outs)
    end
    Occur[TType.Tbl] = function(x, node)
        for _, tk in ipairs(node) do
            if occurs(x, tk[1]) or tk[2] and occurs(x, tk[2]) then
                return true
            end
        end
        return false
    end
    Occur[TType.Or] = function(x, node)
        for _, t in ipairs(node) do
            if occurs(x, t) then
                return true
            end
        end
        return false
    end
    local get_lower_bounds = function(tvar)
        if not lower_bounds[tvar.id] then
            lower_bounds[tvar.id] = {}
        end
        return lower_bounds[tvar.id]
    end
    local get_upper_bounds = function(tvar)
        if not upper_bounds[tvar.id] then
            upper_bounds[tvar.id] = {}
        end
        return upper_bounds[tvar.id]
    end
    local add_lower_bound = function(tvar, bound)
        local bounds = get_lower_bounds(tvar)
        bounds[#bounds + 1] = bound
    end
    local add_upper_bound = function(tvar, bound)
        local bounds = get_upper_bounds(tvar)
        bounds[#bounds + 1] = bound
    end
    local merge_bounds = function(tvar1, tvar2)
        local lb1 = get_lower_bounds(tvar1)
        local lb2 = get_lower_bounds(tvar2)
        for _, b in ipairs(lb2) do
            lb1[#lb1 + 1] = b
        end
        local ub1 = get_upper_bounds(tvar1)
        local ub2 = get_upper_bounds(tvar2)
        for _, b in ipairs(ub2) do
            ub1[#ub1 + 1] = b
        end
    end
    local extend = function(tvar, texp, ignore)
        assert(tvar.tag == TType.New)
        if occurs(tvar, texp) then
            return false, ignore and "" or "contains recursive type " .. ty.tostr(tvar) .. " in " .. ty.tostr(texp)
        end
        for id, t in ipairs(subs) do
            subs[id] = subst(t, tvar, texp)
        end
        subs[tvar.id] = texp
        return tvar
    end
    local unify
    local unify_tuple = function(x, y, ignore)
        local i, n = 0, #x
        local t, err
        while i < n do
            i = i + 1
            if y[i] then
                t, err = unify(x[i], y[i], ignore)
                if not t then
                    return false, ignore and "" or "parameter " .. i .. " " .. err
                end
            else
                if not x[i].varargs then
                    return false, ignore and "" or "expects " .. n .. " arguments but only got " .. i - 1
                end
                return x
            end
        end
        n = #y
        if i < n then
            if i < 1 or not x[i].varargs then
                return false, ignore and "" or "expects only " .. i .. " arguments but got " .. n
            end
        end
        return x
    end
    local unify_tbl = function(x, y, ignore)
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
                    local ok, err = unify(ttx[1], vy, ignore)
                    if not ok then
                        return false, err
                    end
                else
                    return false, ignore and "" or "expects key `" .. key_str(ttx[2]) .. "` in " .. ty.tostr(y)
                end
            end
        end
        return x
    end
    unify = function(x, y, ignore)
        if x == y then
            return x
        end
        x = apply(x)
        y = apply(y)
        if x.tag == TType.New and y.tag == TType.New then
            merge_bounds(x, y)
            return extend(x, y)
        end
        if x.tag == TType.New then
            add_upper_bound(x, y)
            return extend(x, y)
        end
        if y.tag == TType.New then
            add_upper_bound(y, x)
            return extend(y, x)
        end
        if x.tag == TType.Any and y.tag ~= TType.Nil then
            return x
        end
        if y.tag == TType.Any and x.tag ~= TType.Nil then
            return x
        end
        if x.tag == TType.Or then
            for _, t in ipairs(x) do
                local tt = unify(t, y, ignore)
                if tt then
                    return tt
                end
            end
        end
        if y.tag == TType.Or then
            for _, t in ipairs(y) do
                local tt = unify(x, t, ignore)
                if tt then
                    return tt
                end
            end
        end
        if x.tag == y.tag then
            if x.tag == TType.Nil then
                return x
            end
            if x.tag == TType.Val then
                if x.type == y.type then
                    return x
                end
            end
            if x.tag == TType.Tuple then
                return unify_tuple(x, y, ignore)
            end
            if x.tag == TType.Func then
                return unify(x.ins, y.ins, ignore)
            end
            if x.tag == TType.Tbl then
                return unify_tbl(x, y, ignore)
            end
        end
        if x.tag == TType.Tuple then
            return unify(x[1] or ty["nil"](), y)
        end
        if y.tag == TType.Tuple then
            return unify(x, y[1] or ty["nil"]())
        end
        return false, ignore and "" or "expects " .. ty.tostr(x) .. " instead of " .. ty.tostr(y)
    end
    local constrain
    local constrain_func = function(a, b)
        local ok1 = constrain(b.ins, a.ins)
        local ok2 = constrain(a.outs, b.outs)
        return ok1 and ok2
    end
    constrain = function(a, b)
        a = apply(a)
        b = apply(b)
        if a == b then
            return true
        end
        if a.tag == TType.New then
            add_upper_bound(a, b)
            return true
        end
        if b.tag == TType.New then
            add_lower_bound(b, a)
            return true
        end
        if a.tag == TType.Or then
            for _, t in ipairs(a) do
                if not constrain(t, b) then
                    return false
                end
            end
            return true
        end
        if b.tag == TType.Or then
            for _, t in ipairs(b) do
                if constrain(a, t) then
                    return true
                end
            end
            return false
        end
        if a.tag == b.tag then
            if a.tag == TType.Nil or a.tag == TType.Any then
                return true
            end
            if a.tag == TType.Val then
                return a.type == b.type
            end
            if a.tag == TType.Func then
                return constrain_func(a, b)
            end
        end
        return false
    end
    return {apply = apply, extend = extend, unify = unify, constrain = constrain}
end
