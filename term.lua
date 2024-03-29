--
-- Generated from term.lt
--
local slash = package.config:sub(1, 1)
local color = {
    reset = "\27[0m"
    , red = "\27[91;1m"
    , green = "\27[92;1m"
    , yellow = "\27[93;1m"
    , blue = "\27[94;1m"
    , magenta = "\27[95;1m"
    , cyan = "\27[96;1m"
    , white = "\27[97;1m"
}
local write = function(...)
    local n = select("#", ...)
    for i = 1, n, 1 do
        io.stdout:write(tostring(select(i, ...)))
    end
end
local usage = function(...)
    write(...)
    os.exit(1)
end
local scan = function(args)
    local yield = coroutine.yield
    local null = ""
    return coroutine.wrap(function()
        local switch = null
        local k = 1
        while args[k] do
            local a = args[k]
            if "-" == string.sub(a, 1, 1) then
                if switch ~= null then
                    yield(switch)
                end
                switch = string.sub(a, 2)
            else
                yield(switch, a)
                switch = null
            end
            k = k + 1
        end
        if switch ~= null then
            yield(switch)
        end
    end)
end
local localize = function(path)
    if slash == "\\" then
        return string.gsub(path, "/", slash)
    end
    return string.gsub(path, "\\", slash)
end
local exec = function(cmd)
    local ok, exit_or_signal, code = os.execute(cmd)
    if code then
        return code
    end
    return ok
end
local mkdir = function(path)
    local cmd
    if slash == "\\" then
        cmd = "md " .. path
    else
        cmd = "mkdir -p " .. path
    end
    local code = exec(cmd)
    if code == 0 then
        return true
    end
    return false, cmd .. " failed, exit code: " .. tostring(code)
end
local exist_dir = function(path)
    local p = string.gsub(path, "/*$", "")
    local code = exec("pushd " .. p .. " 2> nul")
    if code == 0 then
        exec("popd")
    end
    return code == 0
end
local list_files = function(path)
    local cmd
    if slash == "\\" then
        cmd = "dir /b/a:-D \"" .. path .. "\""
    else
        cmd = "/bin/ls -p \"" .. path .. "\" | grep -v /"
    end
    return io.popen(cmd)
end
if slash == "\\" then
    local bit = require("bit")
    local ffi = require("ffi")
    local kernel32 = ffi.load("kernel32")
    ffi.cdef([=[
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
	]=])
    local enable_VT = function()
        local handle = kernel32.GetStdHandle(kernel32.STD_OUTPUT_HANDLE)
        local lpMode = ffi.new("DWORD[1]")
        local res = kernel32.GetConsoleMode(handle, lpMode)
        if res ~= 0 then
            local mode = bit.bor(lpMode[0], kernel32.ENABLE_VIRTUAL_TERMINAL_PROCESSING)
            res = kernel32.SetConsoleMode(handle, mode)
            if res ~= 0 then
                return true
            end
        end
        return false
    end
    if not enable_VT() then
        color = setmetatable({}, {__index = function()
            return ""
        end})
    end
end
return {
    slash = slash
    , color = color
    , write = write
    , usage = usage
    , scan = scan
    , localize = localize
    , mkdir = mkdir
    , exist_dir = exist_dir
    , list_files = list_files
}
