
1. Why is `:` not supported? Explicitly specifying `@` or `self` is ugly.
2. Why is `function f(x)` statement not supported?

Both `:` and function statement are [syntactic sugar](https://www.lua.org/manual/5.1/manual.html#2.5.9) in Lua.
They are not usable in every situation. Consider:

```
-- Declaration
local t = {
  num = 10
  , e = function(self, n)                        -- neither function statement nor `:` can be used
    return self.num - n
}

-- function t:['long-name'](...) end             -- not valid

-- Invocation
t['long-name'](t, n)                             -- cannot use `:`, t need to be specified explicitly
```


It actually gets better in Luaty. Using `@` for invocation *just works*.
```
t['long-name'](@, n)
```
In the Lua output, `t` will be evaluated only once, as specified by [the manual](https://www.lua.org/manual/5.1/manual.html#2.5.8).


Luaty prefers [*only one way to do it*](https://wiki.python.org/moin/TOOWTDI). Whenever a (function) declaration is needed in Luaty, it always starts with

```
var xxx = ....
```


3. Why is parenthesis needed when calling function with a table or a string? 

By the same [*philosophy*](https://wiki.python.org/moin/TOOWTDI), when there are more than one arguments, explicit parenthesis is the only way that works.
