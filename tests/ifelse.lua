--
-- Generated from ifelse.lt
--

if false then
end
if false then
else
end
if false then
elseif false then
elseif false then
    if false then
        if true then
        end
    else
    end
else
end
local x = false
local y
if x then
    y = 1
else
    y = 2
end
assert(y == 2)
local odd = function(n)
    return n % 2 == 1
end
if odd(8) then
    y = 1
else
    y = 2
end
assert(y == 2)
local fact
fact = function(n)
    if n <= 1 then
        return 1
    else
        return n * fact(n - 1)
    end
    return 10
end
assert(120 == fact(5))
local foo = function(x, y)
    if x < y then
        if x * x < y * y then
            if x + y < x - y then
                return x
            else
                return y
            end
        else
            return y * y
        end
    else
        if x + y > x - y then
            return x - y
        end
        return x + y
    end
end
assert(foo(3, 4) == 4)
assert(foo(4, 3) == 1)
local none = function()
    local c = "="
    local esc = false
    if esc then
        return "!"
    elseif c == "~" then
        esc = true
        if c ~= "=" then
            return "#"
        else
            c = "-"
            return c
        end
    elseif c == "\"" or c == "'" then
    elseif c == "!" then
    else
        if not c then
            error("invalid c")
        end
        return c
    end
end
assert(none() == "=")