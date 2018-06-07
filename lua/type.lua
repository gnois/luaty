--
-- Generated from type.lt
--
local ast = require("lua.ast")
local Tag = require("lua.tag")
local TType = Tag.Type
return function(warn)
    local subs = {}
    local err = function(t, msg)
        warn(t.line, t.col, 1, msg)
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
    Subst[TType.Ref] = function(node, tvar, texp)
        if node.params then
            local params, returns = {}, {}
            for i, p in ipairs(node.params.types) do
                params[i] = subst(p, tvar, texp)
            end
            for i, r in ipairs(node.returns.types) do
                returns[i] = subst(r, tvar, texp)
            end
            return ast.Type.func(ast.Type.tuple(params, node), ast.Type.tuple(returns, node), node)
        end
        local tytys = {}
        for i, tk in ipairs(node.tytys) do
            tytys[i] = {subst(tk[1], tvar, texp), tk[2] and subst(tk[2], tvar, texp)}
        end
        return ast.Type.tbl(tytys, node)
    end
    Subst[TType.Or] = function(node, tvar, texp)
        local left = subst(node.left, tvar, texp)
        local right = subst(node.right, tvar, texp)
        return ast.Type["or"](left, right, node)
    end
    Subst[TType.And] = function(node, tvar, texp)
        local left = subst(node.left, tvar, texp)
        local right = subst(node.right, tvar, texp)
        return ast.Type["and"](left, right, node)
    end
    local Apply = {}
    local apply = function(ty)
        local rule = Apply[ty.tag]
        if rule then
            return rule(ty)
        end
        return ty
    end
    Apply[TType.New] = function(node)
        return subs[node.id] or node
    end
    Apply[TType.Ref] = function(node)
        if node.params then
            local params, returns = {}, {}
            for i, p in ipairs(node.params.types) do
                params[i] = apply(p)
            end
            for i, r in ipairs(node.returns.types) do
                returns[i] = apply(r)
            end
            return ast.Type.func(ast.Type.tuple(params, node), ast.Type.tuple(returns, node), node)
        end
        local tytys = {}
        for i, tk in ipairs(node.tytys) do
            tytys[i] = {apply(tk[1]), tk[2] and apply(tk[2])}
        end
        return ast.Type.tbl(tytys, node)
    end
    Apply[TType.Or] = function(node)
        local left = apply(node.left)
        local right = apply(node.right)
        return ast.Type["or"](left, right, node)
    end
    Apply[TType.And] = function(node)
        local left = apply(node.left)
        local right = apply(node.right)
        return ast.Type["and"](left, right, node)
    end
    local Occur = {}
    local occurs = function(tx, ty)
        local rule = Occur[tx.tag]
        if rule then
            return rule(tx, ty)
        end
        return false
    end
    Occur[TType.Ref] = function(node, ty)
        if node.params then
            for _, p in ipairs(node.params.types) do
                if occurs(p, ty) then
                    return true
                end
            end
            for _, r in ipairs(node.returns.types) do
                if occurs(r, ty) then
                    return true
                end
            end
            return false
        end
        for _, tk in ipairs(node.tytys) do
            if occurs(tk[1], ty) or tk[2] and occurs(tk[2], ty) then
                return true
            end
        end
        return false
    end
    Occur[TType.Or] = function(node, ty)
        return occurs(node.left, ty) or occurs(node.right, ty)
    end
    Occur[TType.And] = function(node, ty)
        return occurs(node.left, ty) or occurs(node.right, ty)
    end
    local extend = function(tvar, texp)
        assert(tvar.tag == TType.New)
        if occurs(tvar, texp) then
            err(tvar, "cannot infer recursive type")
            return subs
        end
        for id, t in ipairs(subs) do
            subs[id] = subst(t, tvar, texp)
        end
        subs[tvar.id] = texp
    end
    local unify
    local unify_func = function(tx, ty)
        local xs, ys = tx.params.types, ty.params.types
        local i, n = 0, #xs
        while i < n do
            i = i + 1
            if ys[i] then
                unify(xs[i], ys[i])
            else
                if not unify(xs[i], ast.Type["nil"](xs[i])) then
                    err(ty, "too few arguments: taking " .. n .. " but only " .. i - 1 .. " given")
                end
            end
        end
        n = #ys
        if i < n then
            if i < 1 or not xs[i].varargs then
                err(ty, "too many arguments: taking " .. i .. " but only " .. n .. " given")
            end
        end
    end
    local unify_tbl = function(tx, ty)
        
    end
    unify = function(tx, ty)
        tx = apply(tx)
        ty = apply(ty)
        if tx.tag == TType.New then
            extend(tx, ty)
            return 
        end
        if ty.tag == TType.New then
            extend(ty, tx)
            return 
        end
        if tx.tag == TType.Any then
            if tx["nil"] or ty.tag ~= TType["nil"] then
                return 
            end
        end
        if ty.tag == TType.Any then
            if ty["nil"] or tx.tag ~= TType["nil"] then
                return 
            end
        end
        if tx["nil"] and ty.tag == TType["nil"] then
            return 
        end
        if ty["nil"] and tx.tag == TType["nil"] then
            return 
        end
        if tx.tag == ty.tag then
            if tx.tag == TType["nil"] then
                return 
            end
            if tx.tag == TType.Val then
                if tx.type == ty.type then
                    return 
                end
            end
            if tx.tag == TType.Ref then
                if tx.params and ty.params then
                    unify_func(tx, ty)
                    return 
                end
                if tx.tytys and ty.tytys then
                    unify_tbl(tx, ty)
                    return 
                end
            end
        end
        err(ty, "type mismatch: " .. ast.tostr(tx) .. " expected, got " .. ast.tostr(ty))
    end
    return {apply = apply, unify = unify}
end
