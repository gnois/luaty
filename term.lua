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


-- parses command line. returns 2 tables
--   1. map of found switches 
--   2. array of non switch parameters
function scan(args)
    local switches = {}
    local paths, p = {}, 1

    local k = 1
    while args[k] do
        local a = args[k]
        local switch = string.sub(a, 1, 1)
        if switch == "-" then
            switches[string.sub(a, 2)] = true
        else
            paths[p] = a
            p = p + 1
        end
        k = k + 1
    end
    return switches, paths
end


-- result is a table of lexer.warnings
function show_error(result)
    local warns = {}
    for i, m in ipairs(result) do
        warns[i] = string.format(" (%d,%d)" .. color.cyan ..  "  %s" .. color.reset, m.l, m.c, m.msg)
    end
    io.stderr:write(table.concat(warns, "\n") .. "\n")
end


-- Window to support ANSI color

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
		print('Unable to use ANSI colors, error ', GetLastError())
	else
		io.stderr:write(color.magenta, "Using ANSI colors\n", color.reset)
	end
end


return {
    slash = slash
    , color = color
    , usage = usage
    , scan = scan
    , show_error = show_error
}