--
-- Generated from lex.lt
--

local ffi = require("ffi")
local stack = require("lt.stack")
local Keyword = require("lt.reserved")
Keyword.var = true
local int64 = ffi.typeof("int64_t")
local uint64 = ffi.typeof("uint64_t")
local complex = ffi.typeof("complex")
local ASCII_0, ASCII_9 = 48, 57
local ASCII_a, ASCII_f, ASCII_z = 97, 102, 122
local ASCII_A, ASCII_Z = 65, 90
local END_OF_STREAM = -1
local TokenSymbol = {TK_lambda = "->", TK_curry = "~>", TK_ge = ">=", TK_le = "<=", TK_concat = "..", TK_eq = "==", TK_ne = "~=", TK_indent = "<indent>", TK_dedent = "<dedent>", TK_newline = "<newline>", TK_eof = "<eof>"}
local IsNewLine = {["\n"] = true, ["\r"] = true}
local IsEscape = {a = true, b = true, f = true, n = true, r = true, t = true, v = true}
local token2str = function(tok)
    if string.match(tok, "^TK_") then
        return TokenSymbol[tok] or string.sub(tok, 4)
    end
    return tok
end
local char_isalnum = function(c)
    if type(c) == "string" then
        local b = string.byte(c)
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
        local b = string.byte(c)
        return b >= ASCII_0 and b <= ASCII_9
    end
    return false
end
local char_isspace = function(c)
    local b = string.byte(c)
    return b >= 9 and b <= 13 or b == 32
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
        local c = string.sub(str, i, i)
        if char_isalnum(c) then
            t[i] = string.byte(c)
        else
            return nil
        end
    end
    return t
end
local hex_char = function(c)
    if string.match(c, "^%x") then
        local b = bit.band(string.byte(c), 15)
        if not char_isdigit(c) then
            b = b + 9
        end
        return b
    end
end
return function(read, chunkname)
    local data, n, p = nil, 0, 0
    local ch, comment_buff = "", ""
    local buff, bi = {}, 0
    local newline = nil
    local indent = nil
    local minus = nil
    local tabs = nil
    local lookahead = {token = "TK_eof", value = nil}
    local state = {chunkname = chunkname, prevline = 1, prevpos = 1, line = 1, pos = 1, token = "TK_eof", value = nil}
    local fmt_token = function(token)
        if token then
            local tok
            if token == "TK_name" or token == "TK_string" or token == "TK_number" then
                tok = table.concat(buff)
            else
                tok = string.format("'%s'", token2str(token))
            end
            return (string.gsub(tok, "%%.", function(p)
                return "%" .. p
            end))
        end
    end
    local lex_error = function(token, em, ...)
        local tok = fmt_token(token)
        if tok then
            em = em .. " near " .. tok
        end
        local pos = #buff
        if pos > state.pos then
            pos = state.pos
        else
            pos = state.pos - pos
        end
        local msg = string.format("%s: (%d,%d)  " .. em, state.chunkname, state.line, pos, ...)
        error("LT-ERROR" .. msg, 0)
    end
    local popchar = function()
        local k = p
        local c = string.sub(data, k, k)
        p = k + 1
        n = n - 1
        return c
    end
    local fill = function()
        local stream = read()
        if not stream then
            return END_OF_STREAM
        end
        data, n, p = stream, #stream, 1
        return popchar()
    end
    local nextchar = function()
        local c = n > 0 and popchar() or fill()
        state.pos = state.pos + 1
        ch = c
        return c
    end
    local char = function(n)
        local k = p + n
        return string.sub(data, k, k)
    end
    local skip = function(len)
        n = n - len
        p = p + len
    end
    local add_buffer = function(c)
        bi = bi + 1
        buff[bi] = c
    end
    local clear_buffer = function()
        buff, bi = {}, 0
    end
    local get_buffer = function(begin, last)
        return table.concat(buff, "", begin + 1, #buff - last)
    end
    local add_comment = function(str)
        comment_buff = comment_buff .. str
    end
    local get_comment = function()
        local s = comment_buff
        comment_buff = ""
        return s
    end
    local inc_line = function()
        local old = ch
        nextchar()
        if IsNewLine[ch] and ch ~= old then
            nextchar()
        end
        state.line = state.line + 1
        state.pos = 1
    end
    local skip_sep = function()
        local count = 0
        local s = ch
        assert(s == "[" or s == "]")
        add_buffer(s)
        nextchar()
        while ch == "=" do
            add_buffer(ch)
            nextchar()
            count = count + 1
        end
        return ch == s and count or -count - 1
    end
    local lex_number = function()
        local lower = string.lower
        local xp = "e"
        local c = ch
        if c == "0" then
            add_buffer(ch)
            nextchar()
            local xc = ch
            if xc == "x" or xc == "X" then
                xp = "p"
            end
        end
        while char_isalnum(ch) or ch == "." or (ch == "-" or ch == "+") and lower(c) == xp do
            c = lower(ch)
            add_buffer(c)
            nextchar()
        end
        local str = table.concat(buff)
        local x
        if string.sub(str, -1, -1) == "i" then
            local img = tonumber(string.sub(str, 1, -2))
            if img then
                x = complex(0, img)
            end
        elseif string.sub(str, -2, -1) == "ll" then
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
            lex_error("TK_number", "malformed number")
        end
    end
    local read_long_string = function(sep, comment)
        local begin = state.line
        add_buffer(ch)
        nextchar()
        while true do
            local c = ch
            if c == END_OF_STREAM then
                lex_error("TK_eof", (comment and "unfinished long comment" or "unfinished long string") .. " from line %d till", begin)
            elseif c == "]" then
                if skip_sep() == sep then
                    add_buffer(ch)
                    nextchar()
                    break
                end
            else
                add_buffer(c)
                if IsNewLine[c] then
                    inc_line()
                else
                    nextchar()
                end
            end
        end
        return get_buffer(0, 0)
    end
    local read_escape_char = function()
        local c = nextchar()
        local esc = IsEscape[c]
        if esc then
            add_buffer("\\")
            add_buffer(c)
            nextchar()
        elseif c == "x" then
            add_buffer("\\")
            add_buffer(c)
            local ch1 = hex_char(nextchar())
            local hc
            if ch1 then
                add_buffer(ch)
                local ch2 = hex_char(nextchar())
                if ch2 then
                    add_buffer(ch)
                    hc = string.char(ch1 * 16 + ch2)
                end
            end
            if not hc then
                lex_error("TK_string", "invalid escape sequence")
            end
            nextchar()
        elseif c == "z" then
            nextchar()
            while char_isspace(ch) do
                if IsNewLine[ch] then
                    inc_line()
                else
                    nextchar()
                end
            end
        elseif IsNewLine[c] then
            add_buffer("\n")
            inc_line()
        elseif c == "\\" then
            add_buffer("\\")
            add_buffer(c)
            nextchar()
        elseif c == "\"" or c == "'" then
            add_buffer(c)
            nextchar()
        elseif c == END_OF_STREAM then
        else
            if not char_isdigit(c) then
                lex_error("TK_string", "invalid escape character \\" .. c)
            end
            add_buffer("\\")
            add_buffer(c)
            local bc = bit.band(string.byte(c), 15)
            if char_isdigit(nextchar()) then
                add_buffer(ch)
                bc = bc * 10 + bit.band(string.byte(ch), 15)
                if char_isdigit(nextchar()) then
                    add_buffer(ch)
                    bc = bc * 10 + bit.band(string.byte(ch), 15)
                    nextchar()
                end
            end
            if bc > 255 then
                lex_error("TK_string", "invalid escape sequence")
            end
        end
    end
    local read_string = function(delim)
        add_buffer(ch)
        nextchar()
        while ch ~= delim do
            local c = ch
            if c == END_OF_STREAM then
                lex_error("TK_eof", "unfinished string")
            elseif IsNewLine[c] then
                lex_error("TK_string", "unfinished string")
            elseif c == "\\" then
                read_escape_char()
            else
                add_buffer(ch)
                nextchar()
            end
        end
        add_buffer(ch)
        nextchar()
        return get_buffer(1, 1)
    end
    local skip_line = function()
        while not IsNewLine[ch] and ch ~= END_OF_STREAM do
            add_comment(ch)
            nextchar()
        end
    end
    local tokenize = function()
        clear_buffer()
        if newline then
            local ind = newline
            newline = nil
            if ind ~= stack.top() then
                if ind > stack.top() then
                    stack.push(ind)
                    return "TK_indent"
                end
                stack.pop()
                if stack.top() ~= ind then
                    indent = ind
                end
                return "TK_dedent"
            end
        elseif indent then
            if indent > 0 and stack.top() == 0 then
                lex_error(nil, "unaligned or dangling <indent>")
            end
            stack.pop()
            if indent == stack.top() then
                indent = nil
            end
            return "TK_dedent"
        elseif minus then
            minus = nil
            return "-"
        end
        local tab = nil
        local mixed = false
        while true do
            local c = ch
            if IsNewLine[ch] then
                tab = nil
                inc_line()
                local ind = 0
                while ch == " " or ch == "\t" do
                    if not tab then
                        tab = ch
                    elseif tab ~= ch then
                        mixed = true
                    end
                    ind = ind + 1
                    nextchar()
                end
                if ch ~= END_OF_STREAM then
                    newline = ind
                else
                    newline = nil
                end
            elseif ch == END_OF_STREAM then
                if stack.top() > 0 then
                    stack.pop()
                    return "TK_dedent"
                end
                return "TK_eof"
            elseif ch == " " or ch == "\t" or ch == "\b" or ch == "\f" then
                nextchar()
            elseif ch == "-" then
                nextchar()
                if ch == "-" then
                    newline = nil
                    tab = nil
                    mixed = false
                    nextchar()
                    add_comment("--")
                    if ch == "[" then
                        local sep = skip_sep()
                        add_comment(table.concat(buff))
                        clear_buffer()
                        if sep >= 0 then
                            read_long_string(sep, true)
                            add_comment(table.concat(buff))
                            clear_buffer()
                        else
                            skip_line()
                        end
                    else
                        skip_line()
                    end
                    return "TK_comment", get_comment()
                elseif ch == ">" then
                    nextchar()
                    return "TK_lambda"
                elseif newline then
                    minus = true
                else
                    return "-"
                end
            elseif newline then
                if not mixed and tab then
                    if not tabs then
                        tabs = tab
                    elseif tab ~= tabs then
                        mixed = true
                    end
                end
                if mixed then
                    lex_error(nil, "cannot mix tab and space as indentation")
                end
                return "TK_newline"
            else
                if char_isalnum(ch) then
                    if char_isdigit(ch) then
                        return "TK_number", lex_number()
                    end
                    repeat
                        add_buffer(ch)
                        nextchar()
                    until not char_isalnum(ch)
                    local s = get_buffer(0, 0)
                    local reserved = Keyword[s]
                    if reserved then
                        return "TK_" .. s
                    end
                    return "TK_name", s
                elseif ch == "@" then
                    nextchar()
                    return "TK_name", "self"
                elseif ch == "[" then
                    local sep = skip_sep()
                    if sep >= 0 then
                        local str = read_long_string(sep)
                        return "TK_longstring", str
                    elseif sep == -1 then
                        return "["
                    else
                        lex_error("TK_longstring", "long string delimiter error")
                    end
                elseif ch == "=" then
                    nextchar()
                    if ch ~= "=" then
                        return "="
                    else
                        nextchar()
                        return "TK_eq"
                    end
                elseif ch == "<" then
                    nextchar()
                    if ch ~= "=" then
                        return "<"
                    else
                        nextchar()
                        return "TK_le"
                    end
                elseif ch == ">" then
                    nextchar()
                    if ch ~= "=" then
                        return ">"
                    else
                        nextchar()
                        return "TK_ge"
                    end
                elseif ch == "~" then
                    nextchar()
                    if ch == "=" then
                        nextchar()
                        return "TK_ne"
                    elseif ch == ">" then
                        nextchar()
                        return "TK_curry"
                    end
                    return "~"
                elseif ch == ":" then
                    nextchar()
                    if ch ~= ":" then
                        return ":"
                    else
                        nextchar()
                        return "TK_label"
                    end
                elseif ch == "\"" or ch == "'" then
                    local str = read_string(ch)
                    return "TK_string", str
                elseif ch == "." then
                    add_buffer(ch)
                    nextchar()
                    if ch == "." then
                        nextchar()
                        if ch == "." then
                            nextchar()
                            return "TK_dots"
                        end
                        return "TK_concat"
                    elseif not char_isdigit(ch) then
                        return "."
                    else
                        return "TK_number", lex_number()
                    end
                else
                    nextchar()
                    return c
                end
            end
        end
    end
    local lex = function()
        local token, value
        while true do
            token, value = tokenize()
            if token ~= "TK_comment" then
                break
            end
        end
        return token, value
    end
    local step = function()
        state.prevline = state.line
        state.prevpos = state.pos
        if lookahead.token == "TK_eof" then
            state.token, state.value = lex()
        else
            state.token, state.value = lookahead.token, lookahead.value
            lookahead.token = "TK_eof"
        end
        return state.token, state.value
    end
    local next = function()
        if lookahead.token == "TK_eof" then
            lookahead.token, lookahead.value = lex()
        end
        return lookahead.token, lookahead.value
    end
    local throw = function(state, em, ...)
        local msg = string.format("%s: (%d,%d)  " .. em, state.chunkname, state.line, state.prevpos, ...)
        error("LT-ERROR" .. msg, 0)
    end
    local lexer = setmetatable(state, {__index = {tostr = token2str, error = throw, step = step, next = next}})
    nextchar()
    if ch == "\xef" and n >= 2 and char(0) == "\xbb" and char(1) == "\xbf" then
        n = n - 2
        p = p + 2
        nextchar()
    end
    stack.push(0)
    if ch == "#" then
        repeat
            nextchar()
            if ch == END_OF_STREAM then
                return lexer
            end
        until IsNewLine[ch]
        inc_line()
    end
    return lexer
end