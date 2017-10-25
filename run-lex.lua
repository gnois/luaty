local lexer = require("lua.lex")
local read = require("lua.read")
local filename = assert(..., "usage: luajit run-lex.lua <filename>")

local ls = lexer(read.file(filename), filename)

repeat
    ls.step()
    print(ls.line ..":"..ls.pos, ls.token, ls.value or '')
until ls.token == "TK_eof"
