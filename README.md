
Luaty
====

Luaty is a Lua dialect with [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule) that resembles Lua and compiles to Lua.
It allows you to code faster using editors without auto completion, and performs simple lint checks during compilation.
If you know Lua, you already know most of Luaty.


Characteristics:
---

- Lesser or shorter keywords
  * Removed `then`, `end`, `do`
  * `local` becomes `var`, `repeat` becomes `do`, `elseif` becomes `else if`, `self` can be `@`

```
var x = false          -- `var` compiles to `local`
if not x
	print('nay')        -- `then` and `end` not needed

```

- Simple lint capability by giving error when
  * Assigning to undeclared (a.k.a global) variable
  * Shadowing another variable in the same scope
  * duplicated key exists in table

```
a = 1              -- Error: undeclared identifier a
var p = print
var p = 'p'        -- Error: shadowing previous var p

var f = \z->
	var z = 10      -- Error: shadowing previous var z

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
	value = 3.142
	, foo = \@, k ->
		return k * @.value    -- @ is equivalent to `self`
}
-- no more ':'
p(obj:foo(2))         -- Error: ')' expected instead of ':'. This is valid in Lua
p(obj.foo(@, 2))      -- Ok, specify @ explicitly. Compiles to obj:foo(2)
p(obj.foo(obj, 2))    -- Ok, achieves the same outcome

```

- table keys and indexers can be keywords

```
var t = {
	var = 7
	, local = 6         -- Invalid in Lua
	, function = 5      -- Invalid in Lua
}

var x = t.var
var y = t.local        -- Invalid in Lua
var z = t.function     -- Invalid in Lua

print(x, y, z)  -- prints 7  6  5

```




The offside (indentation) rule
---
- In general
  * one space equals one tab
  * either tab(s) or space(s) can be used as indent, but not both in one file

- compound statements should start an indented newline
  * analoguous to statements within C curly braces

```
if true
	p(1)
	p(2)

if true p(1) p(2)         -- beware, becomes:  if true then p(1) end p(2)
-- same outcome as above
if true
  p(1)
p(2)

```

- single statement may stay on the same line
  * analoguous to one statement in C without curly brace

```
if x ~= nil if type(x) == "table" p('table') else p('value') else p('nil')
print((-> return 'a', 1)())      -- prints a  1

```

- to support multiple return values, proper indentation is required when passing lamdas as function argument

```
print(pcall(\x ->
	return x
, 10))                                -- prints true, 10
print(pcall(\x-> return x, 10))       -- prints true, nil, 10

```

- indentation is allowed within table definition, but the line having its closing brace should realign back to the starting indentation

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
* assignment operators += -= /= *= %= ..=



Acknowledgment
---
Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).
It inspired by [Moonscript](https://github.com/leafo/moonscript).
