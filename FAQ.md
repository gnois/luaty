

1. Why is `function f(x)` statement not supported?

Consider the case below:

```
local t = {
	num = 10
}

t['special-name'] = function(self, n)     -- function has to be expression, cannot use `:`, `self` parameter needed explicitly
	self.num = self.num + n
end

```
The function statement is not usable in every situation. It is just a [syntactic sugar](https://www.lua.org/manual/5.1/manual.html#2.5.9) in Lua anyway.
By being consistent, whenever a declaration is needed in Luaty, it always starts with
```
var xxx = ....
```
As the saying goes, preferably *there should be only one way to do it* in Luaty.

You could pursue that further by saying that `.x` indexing operator is actually a syntactic sugar for `['x']`, and I am contradicting myself.
But `.` is so ubiquitous and saves us 3 keystrokes everytime.




2. Why is `:` not supported? Explicitly specifying `@` or `self` is more verbose and ugly compared to Lua.

While `:` is convenient, it is not applicable in all cases. Consider

```
-- case A (declaration)
local t = {
  num = 10
  , e = \self, n                   -- cannot use `:`, self arg is needed
    return self.num - n
}

-- case B (invocation)
t['special-name'](t, n)           -- cannot use `:`, t need to be specified explicitly

```
Explicitly specifying self is the only way that works for all cases. 
It gets even better. For case B, using `@` for invocation
```
t['special-name'](@, n)
```
just works. In the Lua output, `t` will be evaluated only once, as specified by [the manual](https://www.lua.org/manual/5.1/manual.html#2.5.8).




3. Why is parenthesis needed when calling function with a table or a string? This has more keystrokes than Lua.

When there are more than one arguments, explicit parenthesis is the only way that works.
