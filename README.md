Luaty
===

*[Lua] with less [ty]ping*

Luaty is a practical but opinionated Lua dialect with [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule). It compiles to Lua and is written in Lua based on the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Its primary raison d'etre is allow faster Lua coding with arguably cleaner syntax.

Characteristics:
---
- Removed or shortened keywords to reduce keystrokes
  * No more `then`, `end`, `do`
  * `local` becomes `var`, `repeat` becomes `do`, `elseif` becomes `else if`, `self` can be `@`

```
var x = false          -- `var` compiles to `local`
if not x
	print('nay')        -- `then` and `end` not needed

```

- Simple lint capability by giving compilation error when
  * Assigning to undeclared (a.k.a global) variable
  * Shadowing another variable in the same scope
  * duplicated key exists in table.

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
- function definition is always a lambda expression with  `->` or `\arg1, arg2 ->`, instead of a statement
- function call always require parenthesis

```
print 'a'             -- Error: '=' expected instead of 'a'. This is valid in Lua
function f()          -- Error: use '->' instead of 'function'
-> print('x')         -- Error: lambda -> must be an expression
(-> print('x'))()     -- Ok, immediately invoked lambda

```

- Optional curried lambda syntax with `\arg1, arg2 ~>`
  * works with 2 or more arguments. `...` varargs is not supported for the obvious reason that we don't know when to stop currying
  * requires [curry()](https://github.com/gnois/luaty/blob/master/lib/curry.lua) or compatible function

```
var curry = require('lib.curry')
var add = \w, x, y, z ~>
	return w + x + y + z

assert(add(4)(7, 8)(9) == add(4, 7, 8, 9))
```

- method call with `:` not supported, `self` or `@` need to be explicitly specified as function parameter instead
  * a function defined inside object is just a function with the object as its namespace

```
var obj = {
	value = 3.142
	, foo = \@, k ->
		return k * @.value    -- @ is equivalent to `self`
}
-- no more ':'
p(obj:foo(2))         -- Error: ')' expected instead of ':'
p(obj.foo(@, 2))      -- Ok, specify @ explicitly, compiles to obj:foo(2)
p(obj.foo(obj, 2))    -- Ok, compiles to obj.foo(obj, 2), but achieve the same outcome

```

- table key and indexer can be keywords

```
-- compiler will bracket ['local'] and ['function']
var t = {
	var = 7
	, local = 6
	, function = 5
}

var x = t.var
var y = t.local
var z = t.function

print(x, y, z)

```

That's it!
Luaty has so few features that its code very much resembles Lua. It's therefore very easy to convert a properly indented Lua code to Luaty, and vice versa. If you knew Lua, you already know most of Luaty.

On the other spectrum, if you'd like a dialect with many more features and an even terser syntax, please see [Moonscript](https://github.com/leafo/moonscript).


The offside (indentation) rule
---
- either tab(s) or space(s) can be used as indent, but not both.

- compound statements always start at an indented newline. (Analoguous to statements within C curly braces)

```
if true
	p(1)
	p(2)

if true p(1) p(2)         -- beware, compiles to:  if true then p(1) end p(2)
-- compiles same as above
if true
  p(1)
p(2)

```

- single statement may stay on the same line. (Analoguous to one statement in C without curly brace)

```
if x ~= nil if type(x) == "table" p('table') else p('value') else p('nil')
print((-> return 'a', 1)())      -- prints a  1

```

To support multiple return values, proper indentation is required when passing lamdas as function argument.

```
print(pcall(\x ->
	return x
, 10))                                -- prints true, 10
print(pcall(\x-> return x, 10))       -- prints true, nil, 10

```
It should be easily visible that the 2nd case has a lambda returning multiple values.


- within table definition {} and call expression (), indentation is allowed until its closing brace or parenthesis, which must realign back to the starting indentation

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

Please see the [tests folder](https://github.com/gnois/luaty/tree/master/tests) for more code examples.


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



Note that the Luaty compiler strives to show meaningful error message with line number.
Please report incorrect/confusing error message as bug.



Status
---

While Luaty is still new, it is already being actively used. However, it's definitely not battle tested.
Unrecognized syntax should hopefully end in compilation error, but in case compilation is successful, do exercise some caution by double checking the Lua output when necessary.

Bug reports are welcomed.

