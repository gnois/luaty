Stack = {}
Stack.__index = Stack

function Stack.new() 
   return setmetatable({}, Stack) 
end
 
-- put a new object onto a stack
function Stack:push(input)
   self[#self+1] = input
end

-- take an object off a stack
function Stack:pop()
   if #self > 0 then
      local output = self[#self]
      self[#self] = nil
      return output
   end
   return nil
end

function Stack:top()
    return self[#self]
end


return Stack