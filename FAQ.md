

1. Why is `function f(x)` statement not supported?

Function statement is just a [syntactic sugar](https://www.lua.org/manual/5.1/manual.html#2.5.9) in Lua. It is not usable in every situation. Consider:

```
local t = {
	num = 10
}

t['special-name'] = function(self, n)     -- function has to be expression, cannot use `:`, `self` parameter needed explicitly
	self.num = self.num + n
end

```

Luaty prefers *only one way to do it* by allowing only function expression. Whenever a declaration is needed in Luaty, it always starts with
```
var xxx = ....
```


2. Why is `:` not supported? Explicitly specifying `@` or `self` is ugly.

While `:` is convenient, it is confusing for beginners when `self` is automagically defined in function definition. 
And it is again not usable in all cases. Consider:

```
-- case A (declaration)
local t = {
  num = 10
  , e = \self, n                  -- cannot use `:`, self arg is needed
    return self.num - n
}

-- case B (invocation)
t['special-name'](t, n)           -- cannot use `:`, t need to be specified explicitly



```
Explicitly specifying self is the only way that works for all cases. It is only 2 more characters. It gets even better in Luaty.

For case B, using `@` for invocation *just works*.
```
t['special-name'](@, n)
```
In the Lua output, `t` will be evaluated only once, as specified by [the manual](https://www.lua.org/manual/5.1/manual.html#2.5.8).



3. Why is parenthesis needed when calling function with a table or a string? This makes DSL ugly.

Again, when there are more than one arguments, explicit parenthesis is the only way that works.
