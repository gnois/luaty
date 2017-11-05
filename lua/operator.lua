--
-- Generated from operator.lt
--

local bit = require("bit")
local binop = {["+"] = 6 * 256 + 6, ["-"] = 6 * 256 + 6, ["*"] = 7 * 256 + 7, ["/"] = 7 * 256 + 7, ["%"] = 7 * 256 + 7, ["^"] = 10 * 256 + 9, [".."] = 5 * 256 + 4, ["=="] = 3 * 256 + 3, ["~="] = 3 * 256 + 3, ["<"] = 3 * 256 + 3, [">="] = 3 * 256 + 3, [">"] = 3 * 256 + 3, ["<="] = 3 * 256 + 3, ["and"] = 2 * 256 + 2, ["or"] = 1 * 256 + 1}
local unary_priority = 8
local ident_priority = 16
local is_binop = function(op)
    return binop[op]
end
local left_priority = function(op)
    return bit.rshift(binop[op], 8)
end
local right_priority = function(op)
    return bit.band(binop[op], 0xff)
end
return {is_binop = is_binop, left_priority = left_priority, right_priority = right_priority, unary_priority = unary_priority, ident_priority = ident_priority}