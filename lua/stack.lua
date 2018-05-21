--
-- Generated from stack.lt
--
local stack, s = {}, 0
local top = function()
    return stack[s]
end
local push = function(input)
    s = s + 1
    stack[s] = input
end
local pop = function()
    local output = stack[s]
    s = s - 1
    return output
end
return {top = top, push = push, pop = pop}
