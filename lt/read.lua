--
-- Generated from read.lt
--
local Slab = 4096 - 32
local string_reader = function(src)
    local pos = 1
    return function()
        local chunk = string.sub(src, pos, pos + Slab)
        pos = pos + #chunk
        return #chunk > 0 and chunk or nil
    end
end
local file_reader = function(filename)
    local f, err
    if filename then
        f, err = io.open(filename, "r")
        if not f then
            io.write(err)
            io.write("\n")
        end
    else
        f = io.stdin
    end
    return function()
        return f and f:read(Slab)
    end
end
return {string = string_reader, file = file_reader}
