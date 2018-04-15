local read = require("lua.read")
local dump = require("lua.dump")
local lex = require("lua.lex")
local parse = require("lua.parse")
local transform = require("lua.transform")

local filename = assert(..., "usage: luajit run-parse.lua <filename>")
local warn = function() end

local reader = read.file(filename)
local lexer = lex(reader, warn)
local tree = parse(lexer, warn)

print(dump(transform(tree)))


