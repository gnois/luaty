--
-- Generated from type.lt
--
local Tag = require("lua.tag")
local TType = Tag.Type
local create = function(tag, node)
    assert("table" == type(node))
    node.tag = tag
    return node
end
local id = 0
local Type = {
    new = function()
        id = id + 1
        return create(TType.New, {id = id})
    end
    , any = function()
        return create(TType.Any, {})
    end
    , ["nil"] = function()
        return create(TType.Nil, {})
    end
    , num = function()
        return create(TType.Val, {type = "num"})
    end
    , str = function()
        return create(TType.Val, {type = "str"})
    end
    , bool = function()
        return create(TType.Val, {type = "bool"})
    end
    , tuple = function(types)
        return create(TType.Tuple, types)
    end
    , func = function(ins, outs)
        return create(TType.Ref, {ins = ins, outs = outs})
    end
    , tbl = function(typetypes)
        return create(TType.Ref, typetypes)
    end
    , ["or"] = function(left, right)
        return create(TType.Or, {left = left, right = right})
    end
    , ["and"] = function(left, right)
        return create(TType.And, {left = left, right = right})
    end
    , index = function(obj, prop)
        return create(TType.Index, {obj = obj, prop = prop})
    end
    , typeof = function(name)
        return create(TType.Typeof, {name = name})
    end
}
local varargs = function(t)
    assert(TType[t.tag])
    t.varargs = true
    return t
end
local tostr
local tolst = function(ls)
    local out = {}
    for i, p in ipairs(ls) do
        out[i] = tostr(p)
    end
    return table.concat(out, ",")
end
local Str = {}
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
    if t.ins then
        local out = {"[", tolst(t.ins), ":", tolst(t.outs), "]"}
        return table.concat(out)
    end
    local out, o = {}, 1
    local val
    for _, ty in ipairs(t) do
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
Str[TType.Or] = function(t)
    return tostr(t.left) .. "|" .. tostr(t.right)
end
Str[TType.And] = function(t)
    return tostr(t.left) .. "&" .. tostr(t.right)
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
    new = Type.new
    , any = Type.any
    , ["nil"] = Type["nil"]
    , num = Type.num
    , str = Type.str
    , bool = Type.bool
    , tuple = Type.tuple
    , func = Type.func
    , tbl = Type.tbl
    , ["or"] = Type["or"]
    , ["and"] = Type["and"]
    , index = Type.index
    , typeof = Type.typeof
    , varargs = varargs
    , same = same
    , tostr = tostr
}
