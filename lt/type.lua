--
-- Generated from type.lt
--
local Tag = require("lt.tag")
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
local TType = Tag.Type
local create = function(tag, node)
    assert("table" == type(node))
    node.tag = tag
    return node
end
local Type = {
    any = function()
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
        return create(TType.Func, {ins = ins, outs = outs})
    end
    , tbl = function(typetypes)
        return create(TType.Tbl, typetypes)
    end
    , ["or"] = function(...)
        local list, l = {}, 1
        for _, t in ipairs({...}) do
            if t.tag == TType.Or then
                for __, tt in ipairs(t) do
                    list[l] = tt
                    l = l + 1
                end
            else
                list[l] = t
                l = l + 1
            end
        end
        local out, o = {}, 0
        for _, t in ipairs(list) do
            local skip = false
            for _, o in ipairs(out) do
                if same(t, o) then
                    skip = true
                    break
                end
            end
            if not skip then
                o = o + 1
                out[o] = t
            end
        end
        return create(TType.Or, list)
    end
    , ["and"] = function(...)
        return create(TType.And, {...})
    end
    , name = function(name)
        return create(TType.Name, {name = name})
    end
    , index = function(obj, idx)
        return create(TType.Index, {obj = obj, idx = idx})
    end
    , typeof = function(var)
        return create(TType.Typeof, {var = var})
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
Str[TType.Any] = function()
    return "<any>"
end
Str[TType.Nil] = function()
    return "<nil>"
end
Str[TType.Val] = function(t)
    return "<" .. t.type .. ">"
end
Str[TType.Func] = function(t)
    return table.concat({"[", tolst(t.ins), ":", tolst(t.outs), "]"})
end
Str[TType.Tbl] = function(t)
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
    if val then
        out[o] = val
    end
    return "{" .. table.concat(out, ", ") .. "}"
end
Str[TType.Or] = function(t)
    local list = {}
    for i, x in ipairs(t) do
        list[i] = tostr(x)
    end
    return table.concat(list, "|")
end
local any_t = Type.any()
local nil_t = Type["nil"]()
local num_t = Type.num()
local str_t = Type.str()
local bool_t = Type.bool()
return {
    any = function()
        return any_t
    end
    , ["nil"] = function()
        return nil_t
    end
    , num = function()
        return num_t
    end
    , str = function()
        return str_t
    end
    , bool = function()
        return bool_t
    end
    , tuple = Type.tuple
    , func = Type.func
    , tbl = Type.tbl
    , ["or"] = Type["or"]
    , ["and"] = Type["and"]
    , name = Type.name
    , index = Type.index
    , typeof = Type.typeof
    , varargs = varargs
    , same = same
    , tostr = tostr
}
