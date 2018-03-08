--
-- Generated from type.lt
--

local ast = require("lua.ast")
local Kinds = {"Void", "Nil", "Any", "Num", "Str", "Bool", "Func", "Tbl", "Or", "And", "Not", "Custom", "Index", "Keyed"}
local make = function(kind, node)
    node.kind = kind
    return node
end
local is_type = function(ty)
    if ty.kind then
        for _, k in ipairs(Kinds) do
            if k == ty.kind then
                return true
            end
        end
    end
    return false
end
local Type = {}
Type["nil"] = function()
    return make(Kinds[2], {})
end
Type.any = function()
    return make(Kinds[3], {})
end
Type.num = function()
    return make(Kinds[4], {})
end
Type.str = function()
    return make(Kinds[5], {})
end
Type.bool = function()
    return make(Kinds[6], {})
end
Type.func = function(params, returns)
    if params then
        for _, t in ipairs(params) do
            assert(is_type(t))
        end
    end
    if returns then
        for _, t in ipairs(returns) do
            assert(is_type(t))
        end
    end
    return make(Kinds[7], {params = params, returns = returns})
end
Type.tbl = function(kvs)
    return make(Kinds[8], {keyvals = kvs})
end
Type["or"] = function(left, right)
    assert(is_type(left))
    assert(is_type(right))
    return make(Kinds[9], {left = left, right = right})
end
Type["and"] = function(left, right)
    assert(is_type(left))
    assert(is_type(right))
    return make(Kinds[10], {left = left, right = right})
end
Type["not"] = function(ty)
    assert(is_type(ty))
    return make(Kinds[11], {ty})
end
Type.custom = function(name)
    return make(Kinds[12], {name = name})
end
Type.index = function(obj, prop)
    return make(Kinds[13], {obj = obj, prop = prop})
end
Type.keyed = function(name)
    return make(Kinds[14], {name = name})
end
Type.varargs = function(node)
    node.varargs = true
end
Type.bracket = function(node)
    node.bracket = true
end
Type.same = ast.same
local subtype
subtype = function(parent, child)
    return false
end
Type.subtype = subtype
return Type