
Luaty
====

Luaty is an opinionated Lua dialect with [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule) and a few features.
The compiler performs basic linting and generates clean Lua code.

Luaty syntax resembles Lua, but is mostly shorter. If you know Lua, you already knew most of Luaty.

After all, it's just a play of *Lua* with less *ty*ping.


Quick start
---

To execute a Luaty source file, use
```
luajit lt.lua source.lt
```

To compile a Luaty *source.lt* file to *dest.lua*, use
```
luajit lt.lua -c source.lt dest.lua
```
The output file is optional, and defaults to *source.lua*



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

- Prefer consistency over syntactic sugar
  * function definition is always a lambda [expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) using  `->` or `\arg1, arg2 ->`
  * function call always require parenthesis
  * colon `:` is not allowed in method definition or call. `self` or `@` need to be explicitly specified as the first lambda parameter

```
print 'a'                          -- Error: '=' expected instead of 'a'. This is valid in Lua

function f()                       -- Error: use '->' instead of 'function'
-> print('x')                      -- Error: lambda expression by itself not allowed
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

- table key can be keywords

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

1. Either tabs or spaces can be used, but not both in a single file, except for comments, which are ignored.
2. Only one statement is allowed per line.

3. Block statements such as `if`, `for`, `while`, `do` and lambda expression `->` can have child statement(s).
   - A single child statement may choose to stay at the same line as its parent
   - Multiple child statements should start at an indented newline
```
if true p(1)                           -- Ok, p(1) is the only child statement of `if`
p(2)

if true p(1) p(2)                      -- Error, two statements at the same line, `if` and p(2)

do                                     -- Ok, multiple child statements are indented
   p(1)
   p(2)

print((-> return 'a', 1)())            -- Ok, immediately invoked one lined lambda expression

if x == nil for y = 1, 10 do until true else if x == 0 p(x) else if x p(x) else assert(not x)
                                       -- Ok, `do` is the sole children of `for`, which in turn is the sole children of `if`
                                       


```

4. An indent is allowed within table constructor/function call, but the line having its closing brace/parenthesis should realign back to its starting indent
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

5. To accomodate multiple assignment/return values, return statement in single lined functions can be ended using semicolon `;` to separate expressions of different scope
```
print(pcall(\x-> return x, 10))                                          -- multiple return values. Prints true, nil, 10

print(pcall(\x -> return x;, 10))                                        -- ok, single lined function ended with `;`. Prints true, 10

print(pcall(\x ->
   return x
, 10))                                                                   -- ok, function ended with dedent. Prints true, 10


var a, b, c = -> var d, e, f = 2, -> return -> return 9;;, 5;, 7
assert(b + c == 12)                                                      -- `;` used to disambiguate multiple assignment/return values

```


See the [tests folder](https://github.com/gnois/luaty/tree/master/tests) for more code examples.

To run tests in the folder, use
```
luajit run-test.lua ./tests
```





Todo
---
* resolve ambiguous syntax (function call x new statement) since we are line sensitive
* static type check
* op assign with LHS and RHS count match
   
   a, b += 1, 3
   
   c, d ..= "la", "s"


Acknowledgment
---
Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Its existence is inspired by [Moonscript](https://github.com/leafo/moonscript).
