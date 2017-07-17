
Luaty
====

Luaty is a Lua dialect with [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule) that compiles to Lua.
It allows you to code faster using editors without auto completion, and helps with basic lint checks during compilation.

Its syntax resembles Lua. If you know Lua, you already know most of Luaty.

Characteristics:
---

- Lesser or shorter keywords
  * Removed `then`, `end`, `do`
  * `local` becomes `var`, `repeat` becomes `do`, `elseif` becomes `else if`, `self` can be `@`

```
var x = false           -- `var` compiles to `local`
if not x
	print('nay')        -- `then` and `end` not needed

```

- Basic lint checking
  * Assigning to undeclared (a.k.a global) variable
  * duplicate variables in the same scope
  * duplicate keys in a table

```
a = 1              -- Error: undeclared identifier a
var p = print
var p = 'p'        -- Error: duplicate var p

var f = \z->
	var z = 10     -- Error: duplicate var z

var tbl = {
	x = 1
	, x = 3       -- Error: duplicate key 'x' in table
}

```

- Prefer consistency over sugar
  * function definition is always a lambda [expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) with  `->` or `\arg1, arg2 ->`, instead of a statement
  * function call always require parenthesis
  * method definition or call with `:` is not supported. `self` or `@` need to be explicitly specified as the first function parameter

```
print 'a'             -- Error: '=' expected instead of 'a'. This is valid in Lua
function f()          -- Error: use '->' instead of 'function'
-> print('x')         -- Error: lambda -> must be an expression
(-> print('x'))()     -- Ok, immediately invoked lambda


var obj = {
	value = 3
	, foo = \@, k ->
		return k * @.value      -- @ is equivalent to `self`
}

p(obj:foo(2))                   -- Error: ')' expected instead of ':'. This is valid in Lua

assert(obj.foo(@, 2) == 6)      -- Ok, specify @ explicitly. Compiles to obj:foo(2)

```

- table keys and indexers can be keywords

```
var e = {
	var = 7
	, local = 6
	, function = 5
	, if = \...-> return ...
	, else = {true, false}
}

assert(e.var == 7)
assert(11 == e.function + e.local)
assert(e.if(e.else)[2] == false)

```




The offside (indentation) rule
---
- Either tab or space can be used, but not both together in a single file.

- compound statements within a block should start an indented newline

```
if true
	p(1)
	p(2)

```

- only one statement may stay at the same line of a beginning block

```
if true p(1) p(2)         -- error, only one statement may stay on the same line with `if`

if true	p(1)              -- ok
p(2)

if x ~= nil if type(x) == "table" p('table') else p('value') else p('nil')             -- ok, if-else is a single statement
print((-> return 'a', 1)())      -- prints a  1

```

- to support multiple return values, proper indentation is required when passing lamdas as function argument

```
print(pcall(\x ->
	return x
, 10))                                -- prints true, 10
print(pcall(\x-> return x, 10))       -- prints true, nil, 10

```

- an indent is allowed within table constructor/function call, but the line having its closing brace/parenthesis should realign back to its starting indentation

```
var y = { 1
	,
	2}              -- Error: <dedent> expected

var z = { 1
	,
	2
}                  -- Ok, last line realign back with a dedent

print(
	1,
	2
	, 3,
4, 5)              -- Ok, last line realign back to `print(`

```

See the [tests folder](https://github.com/gnois/luaty/tree/master/tests) for more code examples.



Usage
---

To run a Luaty source file, use
```
luajit lt.lua source.lt
```

To compile a Luaty source.lt file to source.lua, use
```
luajit lt.lua -c source.lt
```
Output file can also be specified
```
luajit lt.lua -c source.lt dest.lua
```

* Luaty is not battle tested. Check the Lua output as necessary.



Todo
---
* solve ambiguous syntax (function call x new statement) since we are line sensitive
* assignment operators += -= /= *= %= ..=



Acknowledgment
---
Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

It is inspired by [Moonscript](https://github.com/leafo/moonscript).
