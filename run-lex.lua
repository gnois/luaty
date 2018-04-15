local read = require("lua.read")
local lex = require("lua.lex")

local filename = assert(..., "usage: luajit run-lex.lua <filename>")

local reader = read.file(filename)
local ls = lex(reader, function() end)

repeat
    ls.step()
    print(ls.line ..":"..ls.col, ls.token, ls.value or '')
until ls.token == "TK_eof"
