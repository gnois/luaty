--
-- Generated from lex.lt
--

local ffi = require("ffi")
local int64 = ffi.typeof("int64_t")
local uint64 = ffi.typeof("uint64_t")
local complex = ffi.typeof("complex")
local stack = require("lt.stack")
local band = bit.band
local strsub, strbyte, strchar = string.sub, string.byte, string.char
local ASCII_0, ASCII_9 = 48, 57
local ASCII_a, ASCII_f, ASCII_z = 97, 102, 122
local ASCII_A, ASCII_Z = 65, 90
local END_OF_STREAM = -1
local ReservedKeyword = {["and"] = 1, ["break"] = 2, ["do"] = 3, ["else"] = 4, ["elseif"] = 5, ["end"] = 6, ["false"] = 7, ["for"] = 8, ["function"] = 9, ["goto"] = 10, ["if"] = 11, ["in"] = 12, ["local"] = 13, ["nil"] = 14, ["not"] = 15, ["or"] = 16, ["repeat"] = 17, ["return"] = 18, ["then"] = 19, ["true"] = 20, ["until"] = 21, ["while"] = 22, var = 23}
local TokenSymbol = {TK_lambda = "->", TK_curry = "~>", TK_ge = ">=", TK_le = "<=", TK_concat = "..", TK_eq = "==", TK_ne = "~=", TK_indent = "<indent>", TK_dedent = "<dedent>", TK_newline = "<newline>", TK_eof = "<eof>"}
local IsNewLine = {["\n"] = true, ["\r"] = true}
local IsEscape = {a = true, b = true, f = true, n = true, r = true, t = true, v = true}
local token2str = function(tok)
    if string.match(tok, "^TK_") then
        return TokenSymbol[tok] or string.sub(tok, 4)
    else
        return tok
    end
end
local throw = function(chunkname, line, em, ...)
    local emfmt = string.format(em, ...)
    local msg = string.format("%s:%d   %s", chunkname, line, emfmt)
    error("LT-ERROR" .. msg, 0)
end
local fmt_token = function(ls, token)
    if token then
        local tok
        if token == "TK_name" or token == "TK_string" or token == "TK_number" then
            tok = ls.save_buf
        else
            tok = string.format("'%s'", token2str(token))
        end
        return (string.gsub(tok, "%%.", function(p)
            return "%" .. p
        end))
    end
end
local lex_error = function(ls, token, em, ...)
    local tok = fmt_token(ls, token)
    if tok then
        em = string.format("%s near %s", em, tok)
    end
    throw(ls.chunkname, ls.linenumber, em, ...)
end
local parse_error = function(ls, token, em, ...)
    local tok = fmt_token(ls, token)
    if tok then
        em = string.format("%s instead of %s", em, tok)
    end
    throw(ls.chunkname, ls.linenumber, em, ...)
end
local char_isalnum = function(c)
    if type(c) == "string" then
        local b = strbyte(c)
        if b >= ASCII_0 and b <= ASCII_9 then
            return true
        elseif b >= ASCII_a and b <= ASCII_z then
            return true
        elseif b >= ASCII_A and b <= ASCII_Z then
            return true
        else
            return c == "_"
        end
    end
    return false
end
local char_isdigit = function(c)
    if type(c) == "string" then
        local b = strbyte(c)
        return b >= ASCII_0 and b <= ASCII_9
    end
    return false
end
local char_isspace = function(c)
    local b = strbyte(c)
    return b >= 9 and b <= 13 or b == 32
end
local byte = function(ls, n)
    local k = ls.p + n
    return strsub(ls.data, k, k)
end
local skip = function(ls, n)
    ls.n = ls.n - n
    ls.p = ls.p + n
end
local popchar = function(ls)
    local k = ls.p
    local c = strsub(ls.data, k, k)
    ls.p = k + 1
    ls.n = ls.n - 1
    return c
end
local fill = function(ls)
    local data = ls:read_func()
    if not data then
        return END_OF_STREAM
    end
    ls.data, ls.n, ls.p = data, #data, 1
    return popchar(ls)
end
local nextchar = function(ls)
    local c = ls.n > 0 and popchar(ls) or fill(ls)
    ls.current = c
    return c
end
local savebuf = function(ls, c)
    ls.save_buf = ls.save_buf .. c
end
local get_string = function(ls, init_skip, end_skip)
    return strsub(ls.save_buf, init_skip + 1, -(end_skip + 1))
end
local add_comment = function(ls, str)
    if not ls.comment_buf then
        ls.comment_buf = ""
    end
    ls.comment_buf = ls.comment_buf .. str
end
local get_comment = function(ls)
    local s = ls.comment_buf
    ls.comment_buf = ""
    return s
end
local inclinenumber = function(ls)
    local old = ls.current
    nextchar(ls)
    if IsNewLine[ls.current] and ls.current ~= old then
        nextchar(ls)
    end
    ls.linenumber = ls.linenumber + 1
end
local skip_sep = function(ls)
    local count = 0
    local s = ls.current
    assert(s == "[" or s == "]")
    savebuf(ls, s)
    nextchar(ls)
    while ls.current == "=" do
        savebuf(ls, ls.current)
        nextchar(ls)
        count = count + 1
    end
    return ls.current == s and count or -count - 1
end
local build_64int = function(str)
    local u = str[#str - 2]
    local x = u == 117 and uint64(0) or int64(0)
    local i = 1
    while str[i] >= ASCII_0 and str[i] <= ASCII_9 do
        x = 10 * x + (str[i] - ASCII_0)
        i = i + 1
    end
    return x
end
local byte_to_hexdigit = function(b)
    if b >= ASCII_0 and b <= ASCII_9 then
        return b - ASCII_0
    elseif b >= ASCII_a and b <= ASCII_f then
        return 10 + (b - ASCII_a)
    else
        return -1
    end
end
local build_64hex = function(str)
    local u = str[#str - 2]
    local x = u == 117 and uint64(0) or int64(0)
    local i = 3
    while str[i] do
        local n = byte_to_hexdigit(str[i])
        if n < 0 then
            break
        end
        x = 16 * x + n
        i = i + 1
    end
    return x
end
local strnumdump = function(str)
    local t = {}
    for i = 1, #str do
        local c = strsub(str, i, i)
        if char_isalnum(c) then
            t[i] = strbyte(c)
        else
            return nil
        end
    end
    return t
end
local lex_number = function(ls)
    local lower = string.lower
    local xp = "e"
    local c = ls.current
    if c == "0" then
        savebuf(ls, ls.current)
        nextchar(ls)
        local xc = ls.current
        if xc == "x" or xc == "X" then
            xp = "p"
        end
    end
    while char_isalnum(ls.current) or ls.current == "." or (ls.current == "-" or ls.current == "+") and lower(c) == xp do
        c = lower(ls.current)
        savebuf(ls, c)
        nextchar(ls)
    end
    local str = ls.save_buf
    local x
    if strsub(str, -1, -1) == "i" then
        local img = tonumber(strsub(str, 1, -2))
        if img then
            x = complex(0, img)
        end
    elseif strsub(str, -2, -1) == "ll" then
        local t = strnumdump(str)
        if t then
            x = xp == "e" and build_64int(t) or build_64hex(t)
        end
    else
        x = tonumber(str)
    end
    if x then
        return str
    else
        lex_error(ls, "TK_number", "malformed number")
    end
end
local read_long_string = function(ls, sep, comment)
    savebuf(ls, ls.current)
    nextchar(ls)
    while true do
        local c = ls.current
        if c == END_OF_STREAM then
            lex_error(ls, "TK_eof", comment and "unfinished long comment" or "unfinished long string")
        elseif c == "]" then
            if skip_sep(ls) == sep then
                savebuf(ls, ls.current)
                nextchar(ls)
                break
            end
        else
            savebuf(ls, c)
            if IsNewLine[c] then
                inclinenumber(ls)
            else
                nextchar(ls)
            end
        end
    end
    return get_string(ls, 0, 0)
end
local hex_char = function(c)
    if string.match(c, "^%x") then
        local b = band(strbyte(c), 15)
        if not char_isdigit(c) then
            b = b + 9
        end
        return b
    end
end
local read_escape_char = function(ls)
    local c = nextchar(ls)
    local esc = IsEscape[c]
    if esc then
        savebuf(ls, "\\")
        savebuf(ls, c)
        nextchar(ls)
    elseif c == "x" then
        savebuf(ls, "\\")
        savebuf(ls, c)
        local ch1 = hex_char(nextchar(ls))
        local hc
        if ch1 then
            savebuf(ls, ls.current)
            local ch2 = hex_char(nextchar(ls))
            if ch2 then
                savebuf(ls, ls.current)
                hc = strchar(ch1 * 16 + ch2)
            end
        end
        if not hc then
            lex_error(ls, "TK_string", "invalid escape sequence")
        end
        nextchar(ls)
    elseif c == "z" then
        nextchar(ls)
        while char_isspace(ls.current) do
            if IsNewLine[ls.current] then
                inclinenumber(ls)
            else
                nextchar(ls)
            end
        end
    elseif IsNewLine[c] then
        savebuf(ls, "\n")
        inclinenumber(ls)
    elseif c == "\\" then
        savebuf(ls, "\\")
        savebuf(ls, c)
        nextchar(ls)
    elseif c == "\"" or c == "'" then
        savebuf(ls, c)
        nextchar(ls)
    elseif c == END_OF_STREAM then
    else
        if not char_isdigit(c) then
            lex_error(ls, "TK_string", "invalid escape sequence")
        end
        savebuf(ls, "\\")
        savebuf(ls, c)
        local bc = band(strbyte(c), 15)
        if char_isdigit(nextchar(ls)) then
            savebuf(ls, ls.current)
            bc = bc * 10 + band(strbyte(ls.current), 15)
            if char_isdigit(nextchar(ls)) then
                savebuf(ls, ls.current)
                bc = bc * 10 + band(strbyte(ls.current), 15)
                nextchar(ls)
            end
        end
        if bc > 255 then
            lex_error(ls, "TK_string", "invalid escape sequence")
        end
    end
end
local read_string = function(ls, delim)
    savebuf(ls, ls.current)
    nextchar(ls)
    while ls.current ~= delim do
        local c = ls.current
        if c == END_OF_STREAM then
            lex_error(ls, "TK_eof", "unfinished string")
        elseif IsNewLine[c] then
            lex_error(ls, "TK_string", "unfinished string")
        elseif c == "\\" then
            read_escape_char(ls)
        else
            savebuf(ls, ls.current)
            nextchar(ls)
        end
    end
    savebuf(ls, ls.current)
    nextchar(ls)
    return get_string(ls, 1, 1)
end
local skip_line = function(ls)
    while not IsNewLine[ls.current] and ls.current ~= END_OF_STREAM do
        add_comment(ls, ls.current)
        nextchar(ls)
    end
end
local llex = function(ls)
    ls.save_buf = ""
    if ls.newline then
        local ind = ls.newline
        ls.newline = nil
        if ind ~= stack:top() then
            if ind > stack:top() then
                stack:push(ind)
                return "TK_indent"
            end
            stack:pop()
            if stack:top() ~= ind then
                ls.indent = ind
            end
            return "TK_dedent"
        end
    elseif ls.indent then
        if ls.indent > 0 and stack:top() == 0 then
            lex_error(ls, nil, "unaligned or dangling <indent>")
        end
        stack:pop()
        if ls.indent == stack:top() then
            ls.indent = nil
        end
        return "TK_dedent"
    elseif ls.minus then
        ls.minus = nil
        return "-"
    end
    local tabs, mixed = nil, false
    while true do
        local current = ls.current
        if IsNewLine[current] then
            tabs = nil
            inclinenumber(ls)
            local ind = 0
            while ls.current == " " or ls.current == "\t" do
                if not tabs then
                    tabs = ls.current
                elseif tabs ~= ls.current then
                    mixed = true
                end
                ind = ind + 1
                nextchar(ls)
            end
            if ls.current ~= END_OF_STREAM then
                ls.newline = ind
            else
                ls.newline = nil
            end
        elseif current == END_OF_STREAM then
            if stack:top() > 0 then
                stack:pop()
                return "TK_dedent"
            end
            return "TK_eof"
        elseif current == " " or current == "\t" or current == "\b" or current == "\f" then
            nextchar(ls)
        elseif current == "-" then
            nextchar(ls)
            if ls.current == "-" then
                ls.newline = nil
                tabs = nil
                mixed = false
                nextchar(ls)
                add_comment(ls, "--")
                if ls.current == "[" then
                    local sep = skip_sep(ls)
                    add_comment(ls, ls.save_buf)
                    ls.save_buf = ""
                    if sep >= 0 then
                        read_long_string(ls, sep, true)
                        add_comment(ls, ls.save_buf)
                        ls.save_buf = ""
                    else
                        skip_line(ls)
                    end
                else
                    skip_line(ls)
                end
                return "TK_comment", get_comment(ls)
            elseif ls.current == ">" then
                nextchar(ls)
                return "TK_lambda"
            elseif ls.newline then
                ls.minus = true
            else
                return "-"
            end
        elseif ls.newline then
            if not mixed and tabs then
                if not ls.tabs then
                    ls.tabs = tabs
                elseif tabs ~= ls.tabs then
                    mixed = true
                end
            end
            if mixed then
                lex_error(ls, nil, "cannot mix tab and space as indentation")
            end
            return "TK_newline"
        else
            if char_isalnum(current) then
                if char_isdigit(current) then
                    return "TK_number", lex_number(ls)
                end
                repeat
                    savebuf(ls, ls.current)
                    nextchar(ls)
                until not char_isalnum(ls.current)
                local s = get_string(ls, 0, 0)
                local reserved = ReservedKeyword[s]
                if reserved then
                    return "TK_" .. s
                end
                return "TK_name", s
            elseif current == "@" then
                nextchar(ls)
                return "TK_name", "self"
            elseif current == "[" then
                local sep = skip_sep(ls)
                if sep >= 0 then
                    local str = read_long_string(ls, sep)
                    return "TK_longstring", str
                elseif sep == -1 then
                    return "["
                else
                    lex_error(ls, "TK_longstring", "delimiter error")
                end
            elseif current == "=" then
                nextchar(ls)
                if ls.current ~= "=" then
                    return "="
                else
                    nextchar(ls)
                    return "TK_eq"
                end
            elseif current == "<" then
                nextchar(ls)
                if ls.current ~= "=" then
                    return "<"
                else
                    nextchar(ls)
                    return "TK_le"
                end
            elseif current == ">" then
                nextchar(ls)
                if ls.current ~= "=" then
                    return ">"
                else
                    nextchar(ls)
                    return "TK_ge"
                end
            elseif current == "~" then
                nextchar(ls)
                if ls.current == "=" then
                    nextchar(ls)
                    return "TK_ne"
                elseif ls.current == ">" then
                    nextchar(ls)
                    return "TK_curry"
                end
                return "~"
            elseif current == ":" then
                nextchar(ls)
                if ls.current ~= ":" then
                    return ":"
                else
                    nextchar(ls)
                    return "TK_label"
                end
            elseif current == "\"" or current == "'" then
                local str = read_string(ls, current)
                return "TK_string", str
            elseif current == "." then
                savebuf(ls, ls.current)
                nextchar(ls)
                if ls.current == "." then
                    nextchar(ls)
                    if ls.current == "." then
                        nextchar(ls)
                        return "TK_dots"
                    end
                    return "TK_concat"
                elseif not char_isdigit(ls.current) then
                    return "."
                else
                    return "TK_number", lex_number(ls)
                end
            else
                nextchar(ls)
                return current
            end
        end
    end
end
local do_lex = function(ls)
    local token, value
    while true do
        token, value = llex(ls)
        if token ~= "TK_comment" then
            break
        end
    end
    return token, value
end
local Lexer = {token2str = token2str, error = parse_error}
Lexer.next = function(ls)
    ls.lastline = ls.linenumber
    if ls.tklookahead == "TK_eof" then
        ls.token, ls.tokenval = do_lex(ls)
    else
        ls.token, ls.tokenval = ls.tklookahead, ls.tklookaheadval
        ls.tklookahead = "TK_eof"
    end
end
Lexer.lookahead = function(ls)
    if ls.tklookahead == "TK_eof" then
        ls.tklookahead, ls.tklookaheadval = do_lex(ls)
    end
    return ls.tklookahead, ls.tklookaheadval
end
local LexerClass = {__index = Lexer}
local lex_setup = function(read_func, chunkname)
    local header = false
    local ls = {n = 0, tklookahead = "TK_eof", linenumber = 1, lastline = 1, read_func = read_func, chunkname = chunkname, tabs = nil}
    stack:push(0)
    nextchar(ls)
    if ls.current == "\xef" and ls.n >= 2 and byte(ls, 0) == "\xbb" and byte(ls, 1) == "\xbf" then
        ls.n = ls.n - 2
        ls.p = ls.p + 2
        nextchar(ls)
        header = true
    end
    if ls.current == "#" then
        repeat
            nextchar(ls)
            if ls.current == END_OF_STREAM then
                return ls
            end
        until IsNewLine[ls.current]
        inclinenumber(ls)
        header = true
    end
    return setmetatable(ls, LexerClass)
end
return lex_setup