Luaty
===

*[Lua] with less [ty]ping*

Luaty is a opinionated Lua dialect with offside syntax like Coffeescript. It is written in Lua based on the excellent [Luajit Language Toolkit](https://github.com/franko/luajit-lang-toolkit), and compiles to Lua. 

Its primary raison d'etre is allow faster Lua coding with arguably cleaner syntax. Many Coffeescript features like class, comprehension etc... are simply absent. For a much more feature-rich Coffeescript clone, please see [Moonscript](https://github.com/leafo/moonscript).

Characteristics:
---
- Enforced safety through compilation error when
  * Assigning to undeclared (a.k.a global) variable
  * Shadowing another variable of the same scope
- Reduced typing with less or shorter keywords
  * No `end`, `then`, `do` after `for` and `while`. 
  * `local` is changed to `var`, `repeat` to `do`, `elseif` becomes `else if`, `function` to `fn`, `self` can be `@`.
- Prefer consistency over syntactic sugar
  * function definition is always an expression instead of statement
  * function call always need parenthesis
  * `:` not supported, `self` or `@` need to be explicitly specified as function parameter instead

That's it! Luaty has little features so that you know Luaty if you knew Lua. It's therefore very easy to hand convert a properly indented Lua code to Luaty.


The offside (indentation) rule 
---
1. tabs or spaces can be used as indent, but not both. 
2. compound statements (a block) always start at an indented newline
3. single statement may stay on the same line
4. statements and expressions are newline sensitive, but not table definition


Example:
---
```
a = 1           -- Error: undeclared identifier a
var p = print
var p = 'p'     -- Error: shadowing previous var p
p 'nil'         -- Error: '=' expected instead of ''a''. * Valid in Lua
function f()    -- Error: use 'fn' instead of 'function'
fn f()          -- Error: fn() must be an expression

-- offside rule 3. single statement can be on the same line
if x ~= nil if type(x) == "table" p('table') else p('value') else p('nil')
p((fn()	return 'a', 1)())

-- offside rule 2. Multiple statement should start a new block
if true p(1) p(2)    -- beware, compiles to:    if true then p(1) end p(2)
-- same as above
if true
  p(1)
p(2)

-- function is always expression, and `self` if any must be explicit
var foo = fn(@, k)
  return k * @.value    -- @ is equivalent to `self`
var obj = { 
  value = 3.142,
  foo = foo 
}
-- no more ':'
p(obj:foo(2))     -- Error: ')' expected instead of ':'
p(obj.foo(@, 2))  -- use this instead

```

The Luaty compiler uses handwritten lexer/parser, and emphasis on showing meaningful error message with line number.
To run a Luaty source file, use
```
luajit lt.lua source.lt
```
To compile a Luaty source file to Lua, use
```
luajit lt.lua -c source.lt > dest.lua
```
Please see the test folder for more code examples.


Known issues
---
As `fn` and `var` are introduced as keywords, Luaty could not compile codes that reference existing libararies having these identifiers.
Eg:
```
p(obj.fn)  -- Error: 'name' expected instead of fn
p(obj.var)  -- ok
p(obj.var )  -- Error: 'name' expected instead of var
```
Notice that `p(obj.var)` works because the lexer is hacked to interpret `var` as keyword only if it is followed by a whitespace.
This a tradeoff as `local` and `function` are easily the two most used keywords in Lua. 


Status
---
Luaty is still new so do expect some bugs. 


