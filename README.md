Luaty is yet another indent sensitive language that compiles to Lua.
It has a static analyzer with optional limited type inference, and some opinionated syntax.


Differences from Lua
---

Due to [offside syntax](https://en.wikipedia.org/wiki/Off-side_rule), Luaty could use less syntax boilerplate than Lua:
  * no more `end`
  * no more `do` after `for` and `while`
  * no more `then` after `if`

There are also some syntax changes:
  * `repeat` becomes `do`
  * `elseif` becomes `else if`
  * `local` becomes `var`
  * `[[` and `]]` become backquote(s) \` that can be repeated multiple times
  * table keys can be string or keyword


```
var x = false               -- `var` compiles to `local`
if not x
   print(`"nay"`)           -- `then` and `end` not needed, `"nay"` compiles to [["nay"]]

--`` this is a long
comment ``
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


Unlike Lua, functions in Luaty are mostly desugared:
  * function is defined using [lambda expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) with `->` or `\param1, param2, ... ->`
  * function call always require parenthesis
  * colon `:` is never used. `self` or `@` is specified as the first paramenter or call argument instead
  * specifying `@` as the first call argument compiles to colon call syntax `:` in Lua, if possible

```

function f(x)                       -- error: use '->' instead of 'function'
\x -> print(x)                      -- error: lambda expression by itself not allowed
(\x -> print(x))(3)                 -- ok, immediately invoked lambda
var f = -> print(3)                 -- ok, lambda with assignment statement, \ optional if no parameter

print 'a'                           -- error: '=' expected instead of 'a'; but this is valid in Lua
print('a')                          -- ok, obviously


var obj = {
   value = 3
   , foo = \@, k ->
      return k * @.value            -- `@` compiles to `self`
   , ['long-name'] = \@, n ->       -- notice this function has a special name, but our function definition stays the same
      return n + @.value
}

print(obj:foo(2))                   -- error: ')' expected instead of ':'
assert(obj.foo(@, 2) == 6)          -- ok, compiles to obj:foo(2)

var get = -> return obj
print(get()['long-name'](@, 10))    -- `@` *just works*, get() is only called once
```

Due to backquote replacing `[[` and `]]`, long comments need one extra hyphen if we want to use the trick in https://www.lua.org/pil/1.3.html

```
-- Uncommenting long comment trick

--`
print(10)         -- commented out
---`              -- ** use 3 hyphens at the end of comment **

-- Now, if we add a single hyphen to the first line, the code is in again:

---`
print(10)         --> 10
---`
```

The differences end here, so that a Lua file can easily be [hand converted](https://github.com/gnois/luaty/tree/master/convert.md) to a Luaty file.

With these changes, we get
- forced local variable declaration
- consistent function definition syntax
- arguably shorter codes




Builtin static analyzer
---

During transpiling, Luaty warns about:
  * unused variables
  * shadowed variables in the parent or the same scope
  * unused labels and illegal gotos
  * assignment to undeclared (global) variables
  * assignment having more expressions on the right side than the left
  * duplicate keys in table constructor

An optional type checker can be enabled to check consistent usage of variables.
It will try to infer a limited subset of Lua, but is probably wrong in non trivial cases for now. Improving the type checker is a work in progress.
Lua code will be generated regardless of warning by the type checker.

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


-- when type checker enabled --
var j = \a -> return a
j(4, 5)                   -- function expects only 1 arguments but got 2

var k = \a -> return a + 0
k('s')                    -- function parameter 1 expects <num> instead of <str>

var p = {q = 5}           
p.q.r = 7                 -- assignment expects {} instead of <num>

```





Quick start
---

Luaty only requires LuaJIT to run. 

Given a main.lt file with its required .lt files under its subfolders, Luaty can optionally transpile and generate a complete mirror folder structure with .lua output.

With LuaJIT in your path, create a command alias for luaty

Linux/Unix shell
```
alias luaty='/path/of/luajit -e "package.path=package.path .. '/path/to/luaty/?.lua'" /path/to/luaty/lt.lua'

```
Windows command prompt
```
doskey luaty=\path\of\luajit -e "package.path=package.path .. '\\path\\to\\luaty\\?.lua'" \path\to\luaty\lt.lua $*
```


To begin a REPL, simple invoke
```
luaty
```

To run a Luaty source file, use
```
luaty /path/to/source
```
source is assumed to end with .lt


Suppose our source files are laid out like below:
```
/
├── src
│   ├── main.lt
    ├── sub.lt
    └── lib/
        ├── foo.lt
        ├── bar.lt
        └── ...
```

To transpile a Luaty *src/main.lt* file and its dependencies to */dst*
```
cd src
luaty main /dst
```
If transpilation succeeds, the output should appear like below, with subfolders mirrored:
```
/
├── dst
│   ├── main.lua
    ├── sub.lua
    └── lib/
        ├── foo.lua
        ├── bar.lua
        └── ...
```
However, do note that Luaty does not understand Lua package.path, which may not be statically resolvable.
By the same reason, dynamically constructed require() is ignored by Luaty as well.

Lua output files will not be overwritten if they exist.
To force overwriting, use ```-f``` switch.

To transpile only *main.lt* file without its dependencies, provide a destination ending with .lua
```
luaty [-f] path/main /out/main.lua
```

Destination without .lua is considered a folder, which will be created if it does not exist. For eg:
```
luaty -f main main.lt
```
The output main.lua and its dependencies goes into main.lt/*.lua, so that output file can never overwrite input.


For all the commands above, type checker can be enabled by adding ```-t``` switch.

To make and overwrite Luaty itself, use
```
luaty -f lt.lt .
```

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

4. A table constructor or function call can be indented, but the line having its closing brace/parenthesis must realign back to its starting indent level.
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

5. For single-lined function, semicolon `;` can be used as function terminator if it causes ambiguity in a list of expressions.
Note that any needed comma after the semicolon does not become optional.
```
print(pcall(\x-> return x, 10))                 -- multiple return values. Prints true, nil, 10

print(pcall(\x -> return x;, 10))               -- ok, single lined function ended with `;`. Prints true, 10

print(pcall(\x ->
   return x
, 10))                                          -- ok, same as above, function ended with dedent. Prints true, 10

var o = { fn = -> return 1, 2;, 3, 4 }          -- use `;` to terminate single-lined function
assert(o[2] == 4)

var a, b = -> var d, e, f = 2, -> return -> return 9;;, 5;, 7
assert(b == 7)                                  -- each `;` terminates one single-lined function
```


See the [tests folder](https://github.com/gnois/luaty/tree/master/tests) for more code examples.




Acknowledgments
---

Luaty is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Some of the tests are stolen from official Lua test suite.
