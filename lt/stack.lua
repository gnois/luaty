local Stack = {}
Stack.__index = Stack
Stack.new = function()
    return setmetatable({}, Stack)
end
Stack.push = function(self, input)
    self[#self + 1] = input
end
Stack.pop = function(self)
    if #self > 0 then
        local output = self[#self]
        self[#self] = nil
        return output
    end
    return nil
end
Stack.top = function(self)
    return self[#self]
end
return Stack