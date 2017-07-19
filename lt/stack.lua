--
-- Generated from stack.lt
--

local stack = {}
local top = function()
    return stack[#stack]
end
local push = function(input)
    stack[#stack + 1] = input
end
local pop = function()
    if #stack > 0 then
        local out = top
        stack[#stack] = nil
        return top
    end
end
return {top = top, push = push, pop = pop}