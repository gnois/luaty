Luaty
===

*[Lua] with less [ty]ping*

Luaty is a opinionated Lua dialect with [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule). It is written in Lua based on the excellent [Luajit Language Toolkit](https://github.com/franko/luajit-lang-toolkit), and compiles to Lua. 

Its primary raison d'etre is allow faster Lua coding with arguably cleaner syntax. 


Characteristics:
---
- Less typing with removed or shorter keywords
  * No more `then`, `end`, `do`
  * `local` becomes `var`, `repeat` becomes `do`, `elseif` becomes `else if`, `function` to `fn`, `self` can be `@`

```
var x = false          -- `var` compiles to `local` 
if not x
	print('nay')   -- `then` and `end` not needed

```

- Compilation error when
  * Assigning to undeclared (a.k.a global) variable
  * Shadowing another variable in the same scope

```
a = 1           -- Error: undeclared identifier a
var p = print
var p = 'p'     -- Error: shadowing previous var p

```

- Consistency is prefered over syntactic sugar
  * function definition is always an expression instead of statement
  * function call always need parenthesis
  * `:` not supported, `self` or `@` need to be explicitly specified as function parameter instead

```
print 'a'           -- Error: '=' expected instead of 'a'. This is valid in Lua
function f()    -- Error: use 'fn' instead of 'function'
fn f()          -- Error: fn() must be an expression

-- `self` if any, must be explicit
var foo = fn(@, k)
  return k * @.value    -- @ is equivalent to `self`
var obj = { 
  value = 3.142,
  foo = foo 
}
-- no more ':'
p(obj:foo(2))       -- Error: ')' expected instead of ':'
p(obj.foo(@, 2))    -- ok, use this instead

```

That's it! 
Luaty has so few features that its code very much resembles Lua. It's therefore very easy to convert a properly indented Lua code to Luaty, and vice versa. If you knew Lua, you already knew most of Luaty.


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
print((fn() return 'a', 1)())      -- prints a  1

-- newline makes a difference
print(pcall(fn(x) 
	return x
, 10))                              -- prints true, `10`
print(pcall(fn(x) return x, 10))    -- prints true, nil, 10

```

- within table definition {} and call expression (), indentation is allowed until its closing brace or parenthesis, which must realign back to the starting indentation

```
var y = { 1
	, 
	2}         -- Error: <dedent> expected

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

Note that the Luaty compiler strives to show meaningful error message with line number. 

Please report incorrect/confusing error message as bug.


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


Limitations
---
As `fn` and `var` are taken as keywords, Luaty could not compile codes that use them as identifiers.
It is an opinionated tradeoff as `local` and `function` are easily the two most used keywords in Lua. 

Eg:
```
p(obj.fn)     -- Error: 'name' expected instead of fn
var t = {
   var= 4     -- ok
   var = 6    -- Error: unexpected var
}
p(t.var)      -- ok
p(obj.var )   -- Error: 'name' expected instead of var

```

Notice that `p(t.var)` and `var= 4` in table `t` still works because hack is done to interpret `var` as keyword only if it is followed by a whitespace.



Status
---

While Luaty is still new, it is already being actively used. However, it's definitely not battle tested.
Unrecognized syntax should hopefully end in compilation error, but in case compilation is successful, do exercise some caution by double checking the Lua output when necessary.

Bug reports are welcomed.


