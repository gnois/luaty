
Luaty is another language with [off-side rule](https://en.wikipedia.org/wiki/Off-side_rule) that transcompiles into clean Lua.
Its syntax is brief yet unambiguous, with a compiler that is relatively unforgiving.
The compiler itself is written in Luaty and compiled into Lua.


Why Luaty
---
Because it's a shame there are [so few](https://github.com/jashkenas/coffeescript/wiki/list-of-languages-that-compile-to-js) Lua code generators, yet Lua is one of the [fastest](http://wren.io/performance.html) dynamic language available today.
Luaty is just Lua with a syntactic skin that is likely more readable, shorter or safer.
Its philosophy follows [*"There should be only one way to do it"*.](https://wiki.python.org/moin/TOOWTDI)


Quick start
---

Luaty only requires LuaJIT to run. With LuaJIT in your path, clone this repo, and cd into it.

To execute a Luaty source file, use
```
luajit lt.lua /path/to/source.lt
```

To compile a Luaty *source.lt* file to *dest.lua*, use
```
luajit lt.lua -c /path/to/source.lt dest.lua
```
The output file is optional, and defaults to *source.lua*


To run tests in the [tests folder](https://github.com/gnois/luaty/tree/master/tests), use
```
luajit run-test.lua
```


Differences from Lua
---

Aside from being indent based, most syntaxes of Lua are kept, so that if you know Lua, you already knew most of Luaty.

Here goes the differences:

- Less or shorter keywords
  * no more `then`, `end`, `do`
  * `local` becomes `var`
  * `elseif` becomes `else if`
  * `self` can be `@`

```
var x = false               -- `var` compiles to `local`
if not x
   print('nay')             -- `then` and `end` not needed

```

- Consistency preferred over sugar, ironically
  * function definition is always a [lambda expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) using  `->` or `\arg1, arg2, ... ->`
  * function call always require parenthesis

```

function f(x)                       -- Error: use '->' instead of 'function'
\x -> print(x)                      -- Error: lambda expression by itself not allowed
(\x -> print(x))(3)                 -- Ok, immediately invoked lambda
var f = -> print(3)                 -- Ok, lambda with assignment statement

print 'a'                           -- Error: '=' expected instead of 'a'. This is valid in Lua
print('a')                          -- Ok, obviously

```

- Explicit prefered over implicit
  * colon `:` is not allowed in method definition or call. `self` or `@` has to be explicitly specified as the first lambda parameter

```
var obj = {
   value = 3
   , foo = \@, k ->
      return k * @.value                    -- @ is equivalent to `self`
   , ['long-name'] = \@, n ->
      return n + @.value
}

var ret_o = -> return obj
assert(ret_o()['long-name'](@, 10) == 20)   -- @ *just works*, better than `:`

p(obj:foo(2))                               -- Error: ')' expected instead of ':'. This is valid in Lua
assert(obj.foo(@, 2) == 6)                  -- Ok, specify @ explicitly. Compiles to obj:foo(2)

```

- table keys can be keywords

```
var z = {
   var = 7
   , local = 6
   , function = 5
   , if = \...-> return ...
   , goto = {true, false}
}

assert(z.var == 7)                           -- Ok, z.var works as in Lua
assert(11 == z.function + z.local)           -- Becomes z['function'] and z['local']
assert(z.if(z.goto)[2] == false)             -- Ditto

```



Basic lint checks during compilation
---

Although valid in Lua, Luaty compiler treats these as mistakes:
  * assigning to undeclared (a.k.a global) variable
  * number of values on the right side of multiple assignment is more than the variables on the left side
  * shadowing variables in the parent or same scope
  * duplicate keys in a table

```
a = 1                     -- Error: undeclared identifier a

var c, d = 1, 2, 4        -- Error: assigning 3 values to 2 variables

var p = print
var p = 'p'               -- Error: shadowing previous var p

var f = \z->
   var z = 10             -- Error: shadowing previous var z

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
if true p(1)                    -- Ok, p(1) is the only child statement of `if`
p(2)

if true p(1) p(2)               -- Error, two statements at the same line, `if` and p(2)

do                              -- Ok, multiple child statements are indented
   p(1)
   p(2)

print((-> return 'a', 1)())     -- Ok, immediately invoked one lined lambda expression

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

5. To accomodate multiple assignment/return values, return statement in single lined functions should be ended using semicolon `;` to separate expressions of different scope
```
print(pcall(\x-> return x, 10))                 -- multiple return values. Prints true, nil, 10

print(pcall(\x -> return x;, 10))               -- ok, single lined function ended with `;`. Prints true, 10

print(pcall(\x ->
   return x
, 10))                                          -- ok, function ended with dedent. Prints true, 10


var a, b, c = -> var d, e, f = 2, -> return -> return 9;;, 5;, 7
assert(b == 7)                                  -- `;` used to disambiguate multiple assignment/return values

```


See the [tests folder](https://github.com/gnois/luaty/tree/master/tests) for more code examples.






Todo
---
* resolve ambiguous syntax (function call x new statement) since we are line sensitive
* static type check
* op assign with LHS and RHS count match
   
   a, b += 1, 3
   
   c, d ..= "la", "s"


Acknowledgments
---
Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Its existence is inspired by [Moonscript](https://github.com/leafo/moonscript).
