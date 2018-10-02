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
local clone
clone = function(t)
    if type(t) == "table" then
        local copy = {}
        for i, v in ipairs(t) do
            copy[i] = clone(v)
        end
        for k, v in pairs(t) do
            copy[clone(k)] = clone(v)
        end
        return copy
    end
    return t
end
local TType = Tag.Type
local subtype
local subtype_tuple = function(a, s)
    local i, n = 0, #a
    while i < n do
        i = i + 1
        if s[i] then
            if not subtype(a[i], s[i]) then
                return false
            end
        else
            if not a[i].varargs then
                return false
            end
        end
    end
    if i < #s then
        i = i + 1
        if not s[i].varargs then
            return false
        end
    end
    return true
end
local subtype_func = function(a, s)
    local as, ss = a.ins, s.ins
    local i, n = 0, #as
    while i < n do
        i = i + 1
        if ss[i] then
            if not subtype(ss[i], as[i]) then
                return false
            end
        else
            if not as[i].varargs then
                return false
            end
            return true
        end
    end
    n = #ss
    if i < n then
        if i < 1 or not as[i].varargs then
            return false
        end
    end
    as, ss = a.outs, s.outs
    i, n = 0, #as
    while i < n do
        i = i + 1
        if not subtype(as[i], ss[i]) then
            return false
        end
    end
    return true
end
local subtype_tbl = function(a, s)
    local keys = {}
    local arrty
    for __, tty in ipairs(s) do
        if tty[2] then
            keys[tty[2]] = tty[1]
        else
            assert(not arrty)
            arrty = tty[1]
        end
    end
    for _, ttx in ipairs(a) do
        if ttx[2] then
            local vs = keys[ttx[2]]
            if vs then
                if not subtype(ttx[1], vs) then
                    return false
                end
            else
                return false
            end
        else
            if arrty and not subtype(ttx[1], arrty) then
                return false
            end
        end
    end
    return true
end
subtype = function(a, s)
    if a == s then
        return true
    end
    if a.tag == TType.Or then
        for _, v in ipairs(a) do
            if not subtype(v, s) then
                return false
            end
        end
        return true
    end
    if s.tag == TType.Or then
        for _, v in ipairs(s) do
            if subtype(a, v) then
                return true
            end
        end
        return false
    end
    if a.tag == s.tag then
        if a.tag == TType.Nil then
            return true
        end
        if a.tag == TType.Val then
            if a.type == s.type then
                return true
            end
        end
        if a.tag == TType.Tuple then
            return subtype_tuple(a, s)
        end
        if a.tag == TType.Func then
            return subtype_func(a, s)
        end
        if a.tag == TType.Tbl then
            return subtype_tbl(a, s)
        end
    end
    return false
end
local get_tbl = function(t)
    local tbl = t
    if t.tag == TType.Or then
        for _, v in ipairs(t) do
            if v.tag == TType.Tbl then
                tbl = v
                break
            end
        end
    end
    if tbl.tag == TType.Tbl then
        return tbl
    end
end
local flatten = function(ty, types)
    local list, l = {}, 0
    for _, t in ipairs(types) do
        if t.tag == ty then
            for __, tt in ipairs(t) do
                l = l + 1
                list[l] = tt
            end
        else
            l = l + 1
            list[l] = t
        end
    end
    if l > 1 then
        local out, o = {}, 0
        for _, t in ipairs(list) do
            local skip = false
            for __, v in ipairs(out) do
                if subtype(t, v) then
                    skip = true
                    break
                end
            end
            if not skip then
                o = o + 1
                out[o] = t
            end
        end
        return out
    end
    return list
end
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
        local list = flatten(TType.Or, {...})
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
local Str = {}
local tostr = function(t)
    assert(TType[t.tag])
    local rule = Str[t.tag]
    local s = rule(t)
    if t.varargs then
        return s .. "*"
    end
    return s
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
Str[TType.Tuple] = function(t)
    local out = {}
    for i, v in ipairs(t) do
        out[i] = tostr(v)
    end
    return "(" .. table.concat(out, ", ") .. ")"
end
Str[TType.Func] = function(t)
    return table.concat({tostr(t.ins), "->", tostr(t.outs)})
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
local any_vars_t = varargs(any_t)
local tuple_none_t = Type.tuple({})
local tuple_any_t = Type.tuple({any_vars_t})
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
    , any_vars = function()
        return any_vars_t
    end
    , tuple_none = function()
        return tuple_none_t
    end
    , tuple_any = function()
        return tuple_any_t
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
    , clone = clone
    , get_tbl = get_tbl
    , tostr = tostr
}
