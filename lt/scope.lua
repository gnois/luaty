--
-- Generated from scope.lt
--

local enter_block = function(f, isloop)
    f.block = {prev = f.block, isloop = isloop}
end
local leave_block = function(f)
    f.block = f.block.prev
end
return {enter_block = enter_block, leave_block = leave_block, begin_func = function(pf)
    local f = {parent = pf, vars = {}}
    enter_block(f, false)
    return f
end, end_func = function(f)
    leave_block(f)
    return f.parent
end}