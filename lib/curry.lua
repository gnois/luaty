--
-- Generated from curry.lt
--

return function(len, f)
    local curry
    curry = function(len, parts, f)
        return function(...)
            local args = {...}
            local comb = {}
            local a, c = 0, 0
            while c < #parts do
                c = c + 1
                comb[c] = parts[c]
            end
            while a < #args do
                a = a + 1
                c = c + 1
                comb[c] = args[a]
            end
            if c > len then
                return f(unpack(comb))
            end
            return function(...)
                return curry(len, comb, f)(...)
            end
        end
    end
    return curry(len, {}, f)
end