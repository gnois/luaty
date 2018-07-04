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
local usage = function(text)
    print(text)
    os.exit(1)
end
local scan = function(args)
    local yield = coroutine.yield
    local null = ""
    return coroutine.wrap(function()
        local switch = null
        local k = 1
        while args[k] do
            local arg = args[k]
            if "-" == string.sub(arg, 1, 1) then
                if switch ~= null then
                    yield(switch)
                end
                switch = string.sub(arg, 2)
            else
                yield(switch, arg)
                switch = null
            end
            k = k + 1
        end
        if switch ~= null then
            yield(switch)
        end
    end)
end
local exec = function(cmd)
    print(cmd)
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
    local code = exec("pushd " .. p)
    if code == 0 then
        exec("popd")
    end
    return code == 0
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
    , usage = usage
    , scan = scan
    , mkdir = mkdir
    , exist_dir = exist_dir
}
