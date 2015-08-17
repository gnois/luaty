Luaty
===

*[Lua] with less [ty]ping*

Luaty is a opinionated Lua dialect with offside syntax like Coffeescript. It is written in Lua based on the excellent [Luajit Language Toolkit](https://github.com/franko/luajit-lang-toolkit), and compiles to Lua. 

Its primary raison d'etre is to write Lua faster with arguably cleaner syntax. Many Coffeescript features like class, comprehension etc... are simply absent. For a much more feature-rich Coffeescript clone, please see [Moonscript](https://github.com/leafo/moonscript).

Characteristics:
---
- Enforced safety through compilation error when
  * Assigning to undeclared (a.k.a global) variable
  * Shadowing another variable of the same scope
- Less typing with shorter keywords, and keywords are reduced. 
  * No `end`, `then`, `do` after `for` and `while`. 
  * `local` is changed to `var`, `repeat` to `do`, `elseif` becomes `else if`, `function` to `fn`, `self` can be `@`.
- Prefer consistency over syntactic sugar
	* function definition is always an expression instead of statement
	* function call always need parenthesis
	* `:` not supported, specify `self` or `@` explicitly as function parameter

That's it! Luaty has little features so that you know Luaty if you knew Lua. It's therefore very easy to hand convert a properly indented Lua code to Luaty.

The offside (indentation) rule 
---
1. tabs or spaces can be used as indent, but not both. 
2. compound statements (a block) always start at an indented newline, while single statement may choose not to
3. statements and expressions are newline sensitive, but not table definition

To elaborate rule 2, imagine Luaty indented newline as braces in C/java/C#. When braces are omitted after a control statement (eg, `if`), only the next one statement is taken.
Similary, if newline is not used in Luaty, only the next one statement is taken. Eg: 
`if true p(1) p(2)`
compiles to
```
if true then p(1) end
p(2)
```

Example:
---
```
a = 1  -- Error: undeclared identifier a
var p = print
var p = 'p'  -- Error: shadowing previous var p
p 'nil'    -- Error: '=' expected instead of ''a''. * Valid in Lua
function f()  -- Error: use 'fn' instead of 'function'
fn f()       -- Error: fn() must be an expression

-- statements can be very compact
if x ~= nil if type(x) == "table" p('table') else p(x) else p('nil')
p((fn()	return 'a', 1)())

-- no more ':'
var foo = fn(@, k)
	return k * @.value
var obj = { 
	value = 3.142, 
	foo = foo 
}
p(obj:foo(2))   -- Error: ')' expected instead of ':'
p(obj.foo(@, 2))  -- use this instead

```

The Luaty compiler strives to show meaningful error message with line number. 
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
Note that `p(obj.var)` works because the lexer is hacked to interpret `var` as keyword only if it is followed by a whitespace.
This a tradeoff to save typing as `local` and `function` are easily the two most used keywords in Lua. 


Status
---
Luaty is still new so do expect some bugs. 


