--
-- Generated from tests\number.lt
--

local inc = require("tests.inc")
print(4ull)
local foo = function(n)
    return 1ull * n
end
assert(foo(8) == 8ull)
local n = 0 / 0
local o = 2.35
local xe = 2.35e-6
local ie = 35e-6
local kk = 23455ull
local h = 0x456354
local hf = 0x456354p-06
print(o, xe, ie, kk, z, h, hf)
print(499234445333ll)
print(499234445333ull)
print(0xa34cd34ff09ll)
print(0xa34cd34ff09ull)
print(0xa34cd34ff09ull)
print(0xa34cd34ff09ull)
local bar = function(a)
    local x = 1 / 0
    local y = 0 / 1
    local w = a / 0
    local z = 0 / a
    return x, y, w, z
end
assert(inc.fmt(4, bar(7)) == "inf 0 inf 0")
print(0x31, 0x9e, 0x31ef, 0x9ea1, 0x31ef3c, 0x9ea13c, 0x31ef3cea, 0x9eef3cea, 0x31ef3cea09, 0x9eef3cea09)
print(-0x31, -0x9e, -0x31ef, -0x9ea1, -0x31ef3c, -0x9ea13c, -0x31ef3cea, -0x9eef3cea, -0x31ef3cea09, -0x9eef3cea09)