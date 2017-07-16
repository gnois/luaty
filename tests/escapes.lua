--
-- Generated from tests\escapes.lt
--

local x, y, z = "\97", "\"'\\", "\x65"
print(x)
print(y)
print(z)
local a = "\97lo\10\04923"
local b = "\\\n\r\"''\0"
local c = "\3\v\x44\t\"'"
local d = "\254\v\\\\\"\\'\f"
print(a)
print(b)
print(c)
print(d)
local f = "foobar"
local g = "foobar"
local h = "foo\nbar"
print(f)
print(g)
print(h)
local html = [[
<!DOCTYPE HTML>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta content="IE=edge,chrome=1" http-equiv="X-UA-Compatible"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Title</title>
<link rel="shortcut icon" href="/favicon.ico"/>
</head>
<body>
</body></html>
]]