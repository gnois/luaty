
Luaty is best used when writing new code. On Windows, use:
doskey luaty=luajit -e "package.path=package.path .. 'path-to-luaty\\?.lua'"  path-to-luaty\lt.lua $*

However, you can always convert from a properly indented Lua code to Luaty manually to enjoy its cleaner syntax:

Using a text editor, find and replace -

`local` becomes `var`
Find: `local`
Replace: `var`

Indent using Select, Shft-Tab then Tab

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

Convert normal functions
Find: `function (\w+)\((.*)\)`
Replace: `\1 = \\\2 ->`

Convert member functions
Find: `function (\w+).(\w+)\((.*)\)`
Replace: `\1.\2 = \\\3 ->`


Convert member functions that takes self parameter
Find: `function (\w+):(\w+)\((.*)\)`
Replace: `\1.\2 = \\@, \3 ->`
Cleanup functions taking no argument
Find: `,  ->`
Replace: ` ->`



Compile and fix other compilation errors.
