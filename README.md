Luaty is yet another indent sensitive language with some opinionated syntax that compiles to Lua.
It comes with an optional type checker with limited type inference.


Differences from Lua
---
Less syntax boilerplates
  * no more `end`
  * no more `do` after `for` and `while`
  * no more `then` after `if`

Minor syntactical changes
  * `repeat` becomes `do`
  * `elseif` becomes `else if`
  * `local` becomes `var`
  * `[[` and `]]` become backquote(s) \` that can be repeated multiple times

```
var x = false               -- `var` compiles to `local`
if not x
   print(`"nay"`)           -- `then` and `end` not needed, `"nay"` compiles to [["nay"]]

--`` this is a long
comment ``

```

Literal string or keyword as table key
```
var z = {
   'a-str' = 'a-str'                         -- string as key
   , var = 7                                 -- works as in Lua
   , local = 6                               -- keyword as key
   , function = 5
   , if = \...-> return ...
   , goto = {true, false}
}
assert(z.var == 7)                           -- ok, z.var works as in Lua
assert(z.if(z.goto)[2] == false)             -- works
```


Desugared functions
  * function is defined using [lambda expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) with `->` or `\param1, param2, ... ->`
  * function call always require parenthesis
  * colon `:` is never used. Use `self` or `@` as the first paramenter or call argument instead

```

function f(x)                       -- error: use '->' instead of 'function'
\x -> print(x)                      -- error: lambda expression by itself not allowed
(\x -> print(x))(3)                 -- ok, immediately invoked lambda
var f = -> print(3)                 -- ok, lambda is assigned, \ optional if no parameter

print 'a'                           -- error: '=' expected instead of 'a'; but this is valid in Lua
print('a')                          -- ok obviously

var obj = {
   value = 3
   , foo = \@, k ->
      return k * @.value            -- `@` compiles to `self`
   , ['long-name'] = \@, n ->       -- function with a special name
      return n + @.value
}

print(obj:foo(2))                   -- error: ')' expected instead of ':'
assert(obj.foo(@, 2) == 6)          -- ok, compiles to obj:foo(2)

var ox = -> return obj
print(ox()['long-name'](@, 10))    -- `@` *just works*, get() is only called once
```

The differences end here, so that a Lua file can easily be [hand converted](https://github.com/gnois/luaty/tree/master/convert.md) to a Luaty file.

In return, we enjoy
- often shorter codes
- forced local variable declaration
- consistent function definition syntax
- some features like [luacheck](https://github.com/mpeterv/luacheck), and some others

Due to backquote replacing `[[` and `]]`, long comments need one extra hyphen if we want to use the [uncomment trick](https://www.lua.org/pil/1.3.html)

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




Builtin type analyzer
---

During compilation, Luaty runs a simple static analyzer, which warns about:
  * unused variables
  * shadowed variables in the parent or the same scope
  * unused labels and illegal gotos
  * assignment to undeclared (global) variables
  * assignment having more expressions on the right side than the left
  * duplicate keys in table constructor

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

An optional type checker can be enabled to check consistent usage of variables.
Once enabled, it tries to infer variable types a limited subset of Lua, but is probably wrong in non trivial cases for now. 
Lua code will be generated regardless of warning by the optional type checker.
Improving the type checker is a work in progress.

```
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
With LuaJIT in your path, create a command alias for luaty

Linux/Unix shell
```
alias luaty='/path/of/luajit -e "package.path=package.path .. '/path/to/luaty/?.lua'" /path/to/luaty/lt.lua'

```
Windows command prompt
```
doskey luaty=\path\of\luajit -e "package.path=package.path .. '\\path\\to\\luaty\\?.lua'" \path\to\luaty\lt.lua $*
```


To begin a REPL
```
luaty
```

To run a Luaty source file
```
luaty /path/to/source
```
source is assumed to end with .lt


Given a main.lt file with its required .lt files under its subfolders, Luaty can optionally compile and generate a full mirror folder structure of .lua output files.
Suppose our source files are laid out like below, where *main* requires *sub*, which in turn requires *foo* and *bar* under lib folder:

```
/
├── src
│   ├── main.lt
    ├── sub.lt
    └── lib/
        ├── foo.lt
        ├── bar.lt
        ├── orphan.lt
        └── ...
```

To compile *src/main.lt* file and its dependencies to */dst*
```
cd src
luaty main /dst
```
If compilation succeeds, the output should appear like below, with subfolders mirrored:
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
Since orphan.lt is not required, it will not be processed.
Also, Lua package.path and dynamically constructed require() are not processed, because they are not statically resolvable.


Lua output files will not be overwritten if they exist.
To force overwriting, use `-f` switch.

To compile only *main.lt* file without its dependencies, provide a destination ending with .lua
```
luaty [-f] path/main /out/main.lua
```

Destination without .lua is considered a folder, which will be created if it does not exist. For eg:
```
luaty -f main main.lt
```
The output main.lua and its dependencies goes into main.lt/*.lua, so that output file can never overwrite input.


For all the commands above, type checker can be enabled by adding `-t` switch.

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
