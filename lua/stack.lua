--
-- Generated from stack.lt
--
local stack = {}
local top = function()
    return stack[#stack]
end
local push = function(input)
    table.insert(stack, input)
end
local pop = function()
    return table.remove(stack)
end
return {top = top, push = push, pop = pop}
