-- determine forward or back slash
local slash = package.config:sub(1,1)

-- ansi colors
local color = {
    reset     = "\27[0m"
    , red     = "\27[91;1m"
    , green   = "\27[92;1m"
    , yellow  = "\27[93;1m"
    , blue    = "\27[94;1m"
    , magenta = "\27[95;1m"
    , cyan    = "\27[96;1m"
    , white   = "\27[97;1m"
}

-- print usage and exit
function usage(text)
    io.stderr:write(text)
    os.exit(1)
end

-- parses command line
-- yields switch and its matching parameter if any
function scan(args)
    -- const
    local yield = coroutine.yield
    local null = ""
    
    return coroutine.wrap(function()
        local switch = null
        local k = 1
        while args[k] do
            local arg = args[k]
            if "-" == string.sub(arg, 1, 1) then
                -- previous loop had a switch
                if switch ~= null then
                    yield(switch, null)
                end
                switch = string.sub(arg, 2)
            else
                yield(switch, arg)
                switch = null
            end
            k = k + 1
        end
        if switch ~= null then
            yield(switch, null)
        end
    end)
end



-- result is a table of lexer.warnings
-- returns true if there are errors with severity >= 10
function show_error(result)
    local warns = {}
    for i, m in ipairs(result) do
        local clr = color.yellow
        if m.s >= 10 then
            clr = color.red
        end
        warns[i] = string.format(" (%d,%d)" .. clr ..  "  %s" .. color.reset, m.l, m.c, m.msg)
    end
    if #warns > 0 then
        io.stderr:write(table.concat(warns, "\n") .. "\n")
    end
end


-- Window to support ANSI color, may not work on all Windows version
if slash == '\\' then
	local bit = require("bit")
	local ffi = require("ffi")
	local kernel32 = ffi.load("kernel32")

	ffi.cdef([[
		typedef long BOOL;
		typedef void* HANDLE;
		typedef uint32_t DWORD;
		typedef DWORD* LPDWORD;
		static const int STD_OUTPUT_HANDLE                  = ((DWORD)-11);
		static const int ENABLE_VIRTUAL_TERMINAL_PROCESSING = ((DWORD)4);
		HANDLE GetStdHandle(DWORD nStdHandle);
		BOOL GetConsoleMode(HANDLE hConsoleHandle, LPDWORD lpMode);
		BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
		DWORD GetLastError(void);
	]])

	function enable_VT()
		local handle = kernel32.GetStdHandle(kernel32.STD_OUTPUT_HANDLE)
		local lpMode = ffi.new("DWORD[1]")
		local res = kernel32.GetConsoleMode(handle, lpMode)
		if res ~= 0 then
			local mode = bit.bor(lpMode[0], kernel32.ENABLE_VIRTUAL_TERMINAL_PROCESSING)
			local res = kernel32.SetConsoleMode(handle, mode)
			if res ~= 0 then
				return true
			end
		end
		return false
	end
	if not enable_VT() then
		print('Possibly no ANSI colors support, error ' .. kernel32.GetLastError())
	else
		-- success!
		--io.stderr:write(color.magenta, "Using ANSI colors\n", color.reset)
	end
end


return {
    slash = slash
    , color = color
    , usage = usage
    , scan = scan
    , show_error = show_error
}