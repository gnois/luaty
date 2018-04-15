
Luaty stands for *[Lua] with less [ty]ping*. It's like a rudimentary version of [Moonscript](http://moonscript.org), but comes with a linter.


Builtin linter
---

During transpiling, Luaty warns about:
  * unused variables
  * unused labels
  * assignment to undeclared (a.k.a global) variable
  * assignment having more expressions on the right side than the left
  * shadowed variables in the parent or the same scope
  * duplicate keys in table constructor
  
Lua code will be generated regardless.

```
a = 1                     -- undeclared identifier a

var c, d = 1, 2, 4        -- assigning 3 values to 2 variables

var p = print
var p = 'p'               -- shadowing previous var p

var f = \z->
   var z = 10             -- shadowing previous var z

var tbl = {
   x = 1
   , x = 3                -- duplicate key 'x' in table
}
```


Shorter syntax
---

Aside from having [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule), Luaty is skim on features. Here are the differences from Lua:

- General
  * no more `end`, `then`
  * no more `do` after `for` and `while`
  * `repeat` becomes `do`
  * `local` becomes `var`
  * `elseif` becomes `else if`
  * `[[` and `]]` are replaced with backquote \` which can be repeatable multiple times
  * table keys can accept string or keyword
  
```
var x = false               -- `var` compiles to `local`
if not x
   print(`"nay"`)           -- `then` and `end` not needed, `"nay"` compiles to [["nay"]]

var z = {
   'a-str' = 'a-str'                         -- string as key
   , var = 7                                 -- works as in Lua
   , local = 6                               -- keyword as key
   , function = 5
   , if = \...-> return ...
   , goto = {true, false}
}

assert(z.var == 7)                           -- ok, z.var works as in Lua
assert(11 == z.function + z.local)           -- becomes z['function'] and z['local']
assert(z.if(z.goto)[2] == false)             -- ditto

```

- Functions
  * function declaration is always a [lambda expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) using  `->` or `\arg1, arg2, ... ->`
  * function call always require parenthesis

```

function f(x)                       -- error: use '->' instead of 'function'
\x -> print(x)                      -- error: lambda expression by itself not allowed
(\x -> print(x))(3)                 -- ok, immediately invoked lambda
var f = -> print(3)                 -- ok, lambda with assignment statement

print 'a'                           -- error: '=' expected instead of 'a'. This is valid in Lua
print('a')                          -- ok, obviously
```

- Methods
  * `self` can be `@`
  * colon `:` is never used. `@` specified as the first call argument instead

```
var obj = {
   value = 3
   , foo = \@, k ->
      return k * @.value                    -- @ is equivalent to `self`
   , ['long-name'] = \@, n ->
      return n + @.value
}

var ret_o = -> return obj
assert(ret_o()['long-name'](@, 10) == 20)   -- @ *just works*

assert(obj.foo(@, 2) == 6)                  -- compiles to obj:foo(2)
p(obj:foo(2))                               -- error: ')' expected instead of ':'
```

Lua code is not generated if there is syntax error.




Quick start
---

Luaty only requires LuaJIT to run. 

With LuaJIT in your path, clone this repo, and cd into it.

To execute a Luaty source file, use
```
luajit lt.lua /path/to/source.lt
```

To transpile a Luaty *source.lt* file to *dest.lua*, use
```
luajit lt.lua -c /path/to/source.lt dest.lua
```
The output file is optional, and defaults to *source.lua*


To run tests in the [tests folder](https://github.com/gnois/luaty/tree/master/tests), use
```
luajit run-test.lua
```




The detailed indent (offside) rule
---

1. Either tabs or spaces can be used as indent, but not both in a single file.

2. Comments have no indent rule.

3. Blocks such as `if`, `for`, `while`, `do` and lambda expression `->` can have child statement(s).
   - A single child statement may choose to stay at the same line as its parent
   - Multiple child statements must start at an indented newline
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

4. A table constructor or function call can be indented, but the line having its closing brace/parenthesis must realign back to its starting indent level
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
   , 3,                  -- commas can be anywhere
4, 5)                    -- Ok, last line realign back to `print(`

```

5. A extra semicolon `;` can be used as a terminator for single-lined function if it causes ambiguity in a list of expressions
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




Acknowledgments
---

Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Some of the tests are stolen from official Lua test suite.
