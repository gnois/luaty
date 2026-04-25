--
-- Generated from solve.lt
--
local ty = require("lt.type")
local Tag = require("lt.tag")
local TType = Tag.Type
return function()
    local subs = {}
    local vars = {}
    local ensure_var = function(node)
        assert(node and node.tag == TType.New)
        if not node.sub then
            node.sub = {}
        end
        if not node.sup then
            node.sup = {}
        end
        if not node.level then
            node.level = 0
        end
        vars[node.id] = node
        return node
    end
    local push_unique = function(list, t)
        for _, v in ipairs(list) do
            if v == t or ty.same(v, t) then
                return false
            end
        end
        list[#list + 1] = t
        return true
    end
    local touch = function(node)
        if node and node.tag == TType.New then
            ensure_var(node)
        end
        return node
    end
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
        touch(node)
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
    local extend = function(tvar, texp, ignore)
        assert(tvar.tag == TType.New)
        ensure_var(tvar)
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
        if x.tag == TType.New then
            return extend(x, y)
        end
        if y.tag == TType.New then
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
                local xouts = x.outs or ty.tuple_none()
                local youts = y.outs or ty.tuple_none()
                local ok, err = unify(x.ins, y.ins, ignore)
                if not ok then
                    return false, err
                end
                ok, err = unify(xouts, youts, ignore)
                if not ok then
                    return false, ignore and "" or "return " .. err
                end
                return x
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
    local seen_pair = function(cache, lhs, rhs)
        local row = cache[lhs]
        if not row then
            row = {}
            cache[lhs] = row
        end
        if row[rhs] then
            return true
        end
        row[rhs] = true
        return false
    end
    local same_key = function(a, b)
        if "string" == type(a) or "string" == type(b) then
            return a == b
        end
        return ty.same(a, b)
    end
    local find_field = function(tbl, key)
        for _, tk in ipairs(tbl) do
            if tk[2] and same_key(tk[2], key) then
                return tk[1]
            end
        end
        return nil
    end
    local constrain
    local constrain_tuple = function(lhs, rhs, contra, cache)
        local i, n = 0, #lhs
        while i < n do
            i = i + 1
            if rhs[i] then
                local ok, err
                if contra then
                    ok, err = constrain(rhs[i], lhs[i], cache)
                else
                    ok, err = constrain(lhs[i], rhs[i], cache)
                end
                if not ok then
                    return false, err
                end
            else
                if not lhs[i].varargs then
                    return false, "tuple arity mismatch"
                end
                return true
            end
        end
        if i < #rhs then
            i = i + 1
            if not rhs[i].varargs then
                return false, "tuple arity mismatch"
            end
        end
        return true
    end
    local bind_upper = function(lhs_var, rhs, cache)
        ensure_var(lhs_var)
        rhs = apply(rhs)
        if rhs.tag == TType.New and rhs.id == lhs_var.id then
            return true
        end
        push_unique(lhs_var.sup, rhs)
        for _, low in ipairs(lhs_var.sub) do
            local ok, err = constrain(low, rhs, cache)
            if not ok then
                return false, err
            end
        end
        return true
    end
    local bind_lower = function(rhs_var, lhs, cache)
        ensure_var(rhs_var)
        lhs = apply(lhs)
        if lhs.tag == TType.New and lhs.id == rhs_var.id then
            return true
        end
        push_unique(rhs_var.sub, lhs)
        for _, up in ipairs(rhs_var.sup) do
            local ok, err = constrain(lhs, up, cache)
            if not ok then
                return false, err
            end
        end
        return true
    end
    constrain = function(lhs, rhs, cache)
        lhs = apply(lhs)
        rhs = apply(rhs)
        cache = cache or {}
        if lhs == rhs then
            return true
        end
        if seen_pair(cache, lhs, rhs) then
            return true
        end
        if rhs.tag == TType.Top or lhs.tag == TType.Bot then
            return true
        end
        if lhs.tag == TType.Top and rhs.tag ~= TType.Top then
            return false, "cannot constrain <top> to narrower type"
        end
        if rhs.tag == TType.Bot and lhs.tag ~= TType.Bot then
            return false, "cannot constrain non-bottom to <bot>"
        end
        if rhs.tag == TType.Any and lhs.tag ~= TType.Nil then
            return true
        end
        if lhs.tag == TType.Any then
            if rhs.tag == TType.Any then
                return true
            end
            return false, "<any> is too wide"
        end
        if lhs.tag == TType.New then
            local ok, err = bind_upper(lhs, rhs, cache)
            if not ok then
                return false, err
            end
            if rhs.tag == TType.New then
                ok, err = bind_lower(rhs, lhs, cache)
                if not ok then
                    return false, err
                end
            end
            return true
        end
        if rhs.tag == TType.New then
            return bind_lower(rhs, lhs, cache)
        end
        if lhs.tag == TType.Or then
            for _, t in ipairs(lhs) do
                local ok, err = constrain(t, rhs, cache)
                if not ok then
                    return false, err
                end
            end
            return true
        end
        if rhs.tag == TType.Or then
            for _, t in ipairs(rhs) do
                local ok = constrain(lhs, t, cache)
                if ok then
                    return true
                end
            end
            return false, "cannot fit into union"
        end
        if lhs.tag == TType.And then
            for _, t in ipairs(lhs) do
                local ok, err = constrain(t, rhs, cache)
                if not ok then
                    return false, err
                end
            end
            return true
        end
        if rhs.tag == TType.And then
            for _, t in ipairs(rhs) do
                local ok, err = constrain(lhs, t, cache)
                if not ok then
                    return false, err
                end
            end
            return true
        end
        if lhs.tag == TType.Tuple then
            if rhs.tag == TType.Tuple then
                return constrain_tuple(lhs, rhs, false, cache)
            end
            return constrain(lhs[1] or ty["nil"](), rhs, cache)
        end
        if rhs.tag == TType.Tuple then
            return constrain(lhs, rhs[1] or ty["nil"](), cache)
        end
        if lhs.tag == rhs.tag then
            if lhs.tag == TType.Nil then
                return true
            end
            if lhs.tag == TType.Val then
                if lhs.type == rhs.type then
                    return true
                end
                return false, "primitive mismatch"
            end
            if lhs.tag == TType.Func then
                local lhs_outs = lhs.outs or ty.tuple_none()
                local rhs_outs = rhs.outs or ty.tuple_none()
                local ok, err = constrain_tuple(lhs.ins, rhs.ins, true, cache)
                if not ok then
                    return false, err
                end
                ok, err = constrain_tuple(lhs_outs, rhs_outs, false, cache)
                if not ok then
                    return false, err
                end
                return true
            end
            if lhs.tag == TType.Tbl then
                for _, tk in ipairs(rhs) do
                    if tk[2] then
                        local lv = find_field(lhs, tk[2])
                        if not lv then
                            return false, "missing required field"
                        end
                        local ok, err = constrain(lv, tk[1], cache)
                        if not ok then
                            return false, err
                        end
                    end
                end
                return true
            end
        end
        return false, "cannot constrain " .. ty.tostr(lhs) .. " <: " .. ty.tostr(rhs)
    end
    return {apply = apply, touch = touch, extend = extend, unify = unify, constrain = constrain}
end
