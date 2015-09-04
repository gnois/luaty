
Luaty is best used when writing new code. On Windows, use:
doskey luaty=luajit -e "package.path=package.path .. 'path-to-luaty\\?.lua'"  path-to-luaty\lt.lua $*

However, you can always convert from a properly indented Lua code to Luaty manually to enjoy its cleaner syntax:

Using a text editor, find and replace -

`local` becomes `var`
Find: `local`
Replace: `var`

Remove all `then` and `end`

Find: `then`
Replace:

Find: `end`
Replace:

*Leave the `do` statements intact, but remove `do` after `while` and `for`

Find: `do`
Replace: 

`Repeat` becomes `do`

Find: `repeat`
Replace: `do`


Turn on regular expression

Find: `function (\w+)\(`
Replace: `\1 = fn\(`

Find: `function (\w+):(\w+)\(`
Replace: `\1.\2 = fn\(@, `


Compile and fix other compilation errors.
