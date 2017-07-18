
Luaty
====

Luaty is a Lua dialect with [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule) and less syntatic sugar.
It compiles with basic lint checks to clean Lua.

Its syntax resembles Lua, albeit shorter.
If you know Lua, you already knew most of Luaty.
After all, it's just a play of *Lua* with less *ty*ping.


Quick start
---

To run a Luaty source file, use
```
luajit lt.lua source.lt
```

To compile a Luaty *source.lt* file to *dest.lua*, use
```
luajit lt.lua -c source.lt dest.lua
```
If output file is omitted, it defaults to *source.lua*



Philosophy:
---

- Less or shorter keywords
  * no more `then`, `end`, `do`
  * `local` becomes `var`
  * `repeat` becomes `do`
  * `elseif` becomes `else if`
  * `self` can be `@`

```
var x = false               -- `var` compiles to `local`
if not x
	print('nay')             -- `then` and `end` not needed

```

- Prefer consistency over sugar
  * function definition is always a lambda [expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) using  `->` or `\arg1, arg2 ->`
  * function call always require parenthesis
  * colon `:` is not allowed in method definition or call. `self` or `@` need to be explicitly specified as the first lambda parameter

```
print 'a'                          -- Error: '=' expected instead of 'a'. This is valid in Lua

function f()                       -- Error: use '->' instead of 'function'
-> print('x')                      -- Error: lambda expression by itself not allowed. It should either be immediately invoked or assigned
(-> print('x'))()                  -- Ok, immediately invoked lambda
var f = -> print('x')              -- Ok, lambda with assignment statement

var obj = {
	value = 3
	, foo = \@, k ->
		return k * @.value           -- @ is equivalent to `self`
}

p(obj:foo(2))                      -- Error: ')' expected instead of ':'. This is valid in Lua

assert(obj.foo(@, 2) == 6)         -- Ok, specify @ explicitly. Compiles to obj:foo(2)

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

assert(e.var == 7)                           -- Ok, e.var becomes e['var']
assert(11 == e.function + e.local)           -- Ditto
assert(e.if(e.else)[2] == false)

```



Basic lint checks
---

The compiler treats these as mistakes:
  * assigning to undeclared (a.k.a global) variable 
  * duplicate variables in the same scope
  * duplicate keys in a table

```
a = 1                     -- Error: undeclared identifier a
var p = print
var p = 'p'               -- Error: duplicate var p

var f = \z->
	var z = 10             -- Error: duplicate var z

var tbl = {
	x = 1
	, x = 3                -- Error: duplicate key 'x' in table
}

```





The indent (offside) rule
---

Generally
1. Either tab or space can be used, but not both together in a single file
2. Only one statement is allowed per line

3. Block statements such as `if`, `for`, `while`, `do` and lambda expression `->` can have child statement(s).
   - A single child statement may choose to stay at the same line as its parent
```
if true p(1)                           -- Ok, p(1) is a child statement of `if`
p(2)

if true p(1) p(2)                      -- Error, two statements at the same line, `if` and p(2)

print((-> return 'a', 1)())            -- Ok, immediately invoked one lined lambda expression

if x == nil for y = 1, 10 do until true else if x == 0 assert(x) else if x assert(x) else assert(not x)
-- Ok, `do` is a child of `for`, which in turn is a child statement of `if`
```

   - Multiple child statements should start at an indented newline
```
if true
	p(1)
	p(2)

```

   - proper indent/dedent makes a difference
```
print(pcall(\x ->
	return x
, 10))                                -- prints true, 10
print(pcall(\x-> return x, 10))       -- prints true, nil, 10

```

   - an indent is allowed within table constructor/function call, but the line having its closing brace/parenthesis should realign back to its starting indent
```
var y = { 1
	,
	2}                    -- Error: <dedent> expected

var z = { 1
	,
	2
}                        -- Ok, last line realign back with a dedent

print(
	1,
	2
	, 3,
4, 5)                    -- Ok, last line realign back to `print(`

```

See the [tests folder](https://github.com/gnois/luaty/tree/master/tests) for more code examples.






Todo
---
* resolve ambiguous syntax (function call x new statement) since we are line sensitive
* assignment operators += -= /= *= %= ..=



Acknowledgment
---
Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Its existence is inspired by [Moonscript](https://github.com/leafo/moonscript).
