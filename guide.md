
Luaty is best used when writing new code. On Windows, use:
doskey luaty=luajit -e "package.path=package.path .. 'path-to-luaty\\?.lua'"  path-to-luaty\lt.lua $*

However, you can always convert from a properly indented Lua code to Luaty manually to enjoy its cleaner syntax:

Using a text editor, find and replace -

`local` becomes `var`
Find: `local `
Replace: `var `

`elseif` becomes `else if`
Find: `elseif `
Replace: `else if `

Indent blocks using Select, Shft-Tab then Tab

Remove all `then` and `end`
Find: ` then`
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
Find: `function (\w+)\.(\w+)\((.*)\)`
Replace: `\1.\2 = \\\3 ->`


Convert member functions that take self parameter
Find: `function (\w+)\:(\w+)\((.*)\)`
Replace: `\1.\2 = \\@, \3 ->`

Find: self
Replace: @

Cleanup functions taking no argument
Find: `,  ->`
Replace: ` ->`


Convert calls that take self and other parameters
Find: `(\w+)\:(\w+)\((\w+)`
Replace: `\1.\2(@, \3`

Convert calls that take only self parameters
Find: `(\w+)\:(\w+)\(\)`
Replace: `\1.\2(@)`



Compile and fix other compilation errors.
