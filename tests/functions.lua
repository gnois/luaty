--
-- Generated from functions.lt
--

(function()
end)()
local eq = require("tests.inc").eq
local t = {}
t.bar = function(x)
    return x + 1
end
assert(t.bar(4) == 5)
local arg
local fn = function(arg)
end
arg = 6
fn()
assert(arg == 6)
local tbl = {8, 4, 7, g, h, (function(a, b)
    return a, b
end)("a", "b"), 3}
eq(7, tbl, {8, 4, 7, nil, nil, "a", 3})
local foo
(function(x)
    if x == 1 then
        foo = function(x)
            return x, x * x
        end
    else
        foo = function(x)
            return x
        end
    end
end)(1)
eq(2, {3, 9}, {foo(3)})
eq(3, {(function(...)
    return false, ...
end)(1, "a")}, {false, 1, "a"})
eq(3, {pcall(function(x)
    return x, 10
end)}, {true, nil, 10})
eq(2, {pcall(function(x)
    return x
end, 10)}, {true, 10, nil})
local rr = function(b)
    return function()
        return function()
            return not b, function()
                return b
            end
        end
    end
end
assert(rr(true)()() == false)
local _, r = rr(false)()()
assert(r() == false)
return function()
end