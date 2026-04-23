
2022-10-2

Typed Lua
A second-level type is either a tuple of first-level types optionally ending in a variadic type or a union of these tuples. A variadic
type t* is a generator for a sequence of values of the union type t|nil. The empty tuple () is syntactic sugar to (nil*), as we will show that Typed Lua
always ends a tuple type in a variadic type.
Union of tuple types appear in the return type of function types to represent overloading on the return type.
We can use only one first-level type t in the return type because it is syntactic sugar to the tuple type (t).


-------------------------

Based on above

2022-10-1

8 primitives
nil?, boolean~, number#, string$, function ($?, #$? /return type?), userdata^, thread^, and table  {#,$}, {key1:#,key2:$, $:$}.

: is used for type definition, ONLY allowed at function declaration


Type void (nil) is ? or -, so optional num can be #-, or #?
Type any is *,
Type variadic is .
No typing means variadic any .*,
Grouping uses []

Eg:
() = (...) in lua, so
() means vararg and multi return   (.*/.*),
{} means heterogeneous array or table  {.*:*}


Omit rule 1

function type (...), vararg already known is variadic, so can omit colon and dot and become  (...#)
table type can omit variadic and become {*:*}

Omit rule 2

for table type {*:*}, *:* can be further omitted and become {}


Eg:

heterogeneous table as {#, a:#, b:$, $}
matches  {1, a=7, b='yeh', 'qq', 'rr'}

{#:#} is exactly {#}
{} = {*:*}
{*} = {#:*}
{()} = {#:()} array of func


single element table:  {1:#} or {key3:$}
two element array of funcs:  {1:(), 2:()}
tuple of string, string, bool:  {1:$, 2:$, 3:~)


Function types:
() = (...*/...*),  no annotate, is loose

once annotate, is strict, any omission is ? or -

(/) = (-/-) or (...*/...*) ?
(.*) = (...*/-) or (...*/...*) ?  Lets choose strict, else (.*) is same as (.*/.*)
($/) = takes a str, return ...any or nil ?
(*/*) = takes one any, returns one any
(/-) = takes *... or nil?  return nil or cannot return anything
(...$/...#) = takes vararg of string, return vararg of num
({$}/{1:#}) = takes string array, return num array of one elem




local function idiv (dividend:number, divisor:number):(number, number)|(nil, string)
   if divisor == 0 then
      return nil, "division by zero"
   else
      local r = dividend % divisor
      local q = (dividend - r) // divisor
      return q, r


var idiv = \dividend:#, divisor:# / [#,#][-,$] ->
  ...

var retnil = \...$/-,-->
   return nil, nil



var sort = \arr:{#}, fn:(#,#?~,#,#) /{#}->
   for ..
      var min = fn(a, b)

sort({4,5,7}, \a:#, b:#->
   return a-b, a, b
)



Generics always starts with Capital (so we dont need precede with stuff like <K, V>), generic itself can be constrained with a type!

var sort = \ arr: Input < {#...}, fn: (#, #/Out, #, #) / {#...} ->
   for ...
      var min= fn(a, b)

OR

var sort: (Input < {#...}, (#, #/Out, #, #) / {#...})



Rules:

colon can be omitted?
Eg:

var s#
var y(#,($/#$?) = \a#,fn($/#$?)-> ...

variadic is preceded with ., which can be omitted inside a table {} or preceded by ...
Eg:
variadic num  {.#}



-----------------------------------------------------------


[:] vs [/]
why choose /
because table type can have {num:str,str}, which look similar to function type [num:str,str] but have totally difference meaning, so we use [num/str,str]

function is declared as [num/num]
	\z any/any ->  and \z [any/any] ->
is different


Defaults
----------
[/] means [void/void]
Does ->  means \any/any -> ?
if -> means \void/void ->, all programs will break, which is ok, bcoz nobody uses Luaty :)
And we need this to check that functions are called with correct number of args

So there's no `void` type, bcoz `void` can only be used in function type decl [/], and we simply omit whichever is `void`

----------- BUT this cannot coexist with type inference.

Or
[/] means [any/...any]?
means we need the `void` keyword to indicate no return value [/void]





var f num = 5
var g [num|str/bool] = \x num|str / bool -> return x == 0 || str == '0'
var ff [num,[any/any]/[any/any]] = \n num, x [any/any] / [any/any] ->
	return \a -> return x(x(a))


-- shows why parenthesis needed to determine precedence, thus cannot be used to denote function
var x [num/num|(bool,str)] = \n ->
	if type(n) == 'number'
		return n
	return false, 'Not a number'

`num/num

coroutine
----------
create [[...any/...any]/thread]
resume  [thread, ...any/bool, str|any, ...any]
running  [/thread, bool]
status  [[thread/str]
wrap  [[...any / bool, str|any, ...any] / [...any / bool, str|any, ...any]]
yield  [...any/]




Array of functions
{[str/num]}

