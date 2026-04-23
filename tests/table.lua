--
-- Generated from table.lt
--
local a = {}
local b = {3}
local c = {}
local d = {3}
local e = {3}
local f = {2, 3}
local g = {2, 3}
local h = {2, 3}
local i = {2, 3}
local j = {2, 3}
local k = {2, 3}
local l = {2, 3}
local m = {2, 3}
local n = {2, 3}
local o = {2, 3}
local p = {2, 3}
local q = {2, 3, 4}
local many1 = {{{{{}}}}}
local many2 = {{{{{}}}}}
local many3 = {{{{{}}}}}
local many4 = {{{{{}}}}}
local inc = require("tests.inc")
local name = "secret"
local t = {
    pi = 3.14
    , ciao = "hello"
    , 3
    , 7
    , "boo"
    , 21
}
assert(t.pi == 3.14)
assert(t[1] == 3)
assert(t[2] == 7)
assert(t[3] == "boo")
assert(t[4] == 21)
local s = "0"
local con = {["a" .. s] = 1, ["a" .. s .. "0"] = 2}
local w = {
    pi = 3.14
    , ciao = "hello"
    , 1
    , list = {3, 7, "boum"}
    , 4
    , 9
}
assert(#w.list == 3)
local v = {[0] = 7, 9, 14, 17}
assert(v[0] == 7)
inc.eq(3, v, {9, 14, 17})
assert(({"Go away", "Hello", "Bof"})[2] == "Hello")
local html = {["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;"}
for key, val in pairs(html) do
    print(key .. ": " .. val)
end
local z = {
    var = 7
    , ["local"] = 6
    , ["function"] = 5
    , ["if"] = function(...)
        return ...
    end
    , ["else"] = {true, false}
    , ["goto"] = "goto"
    , [true] = 701
}
assert(4 == z["function"] + z["local"] - z.var)
assert(z["if"](z["else"])[2] == false)
assert(z["goto"] == "goto")
assert(z[true] == 701)
