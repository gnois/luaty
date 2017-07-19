--
-- Generated from read.lt
--

local string_reader = function(src)
    local pos = 1
    return function()
        local chunk = string.sub(src, pos, pos + 4096 - 32)
        pos = pos + #chunk
        return #chunk > 0 and chunk or nil
    end
end
local file_reader = function(filename)
    local f
    if filename then
        f = assert(io.open(filename, "r"), "cannot open file " .. filename)
    else
        f = io.stdin
    end
    return function()
        return f:read(4096 - 32)
    end
end
return {string = string_reader, file = file_reader}