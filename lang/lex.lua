local ffi = require('ffi')
local int64 = ffi.typeof('int64_t')
local uint64 = ffi.typeof('uint64_t')
local complex = ffi.typeof('complex')
local stack = require("lang.stack")

local band = bit.band
local strsub, strbyte, strchar = string.sub, string.byte, string.char

local ASCII_0, ASCII_9 = 48, 57
local ASCII_a, ASCII_f, ASCII_z = 97, 102, 122
local ASCII_A, ASCII_Z = 65, 90

local END_OF_STREAM = -1

local ReservedKeyword = { ['and'] = 1, ['break'] = 2, ['do'] = 3, ['else'] = 4, ['elseif'] = 5, ['end'] = 6, ['false'] = 7, ['for'] = 8, ['function'] = 9, ['goto'] = 10, ['if'] = 11, ['in'] = 12, ['local'] = 13, ['nil'] = 14, ['not'] = 15, ['or'] = 16, ['repeat'] = 17, ['return'] = 18, ['then'] = 19, ['true'] = 20, ['until'] = 21, ['while'] = 22, ['var'] = 23 }

local TokenSymbol = { TK_lambda = '->', TK_curry = '~>', TK_ge = '>=', TK_le = '<=' , TK_concat = '..', TK_eq = '==', TK_ne = '~=', TK_indent = '<indent>', TK_dedent = '<dedent>', TK_newline = '<newline>', TK_eof = '<eof>' }

local IsNewLine = { ['\n'] = true, ['\r'] = true }

local IsEscape = { a = true, b = true, f = true, n = true, r = true, t = true, v = true }
 
local function token2str(tok)
    if string.match(tok, "^TK_") then
        return TokenSymbol[tok] or string.sub(tok, 4)
    else
        return tok
    end
end

local function throw(chunkname, line, em, ...)
    local emfmt = string.format(em, ...)
    local msg = string.format("%s:%d   %s", chunkname, line, emfmt)
    error("LT-ERROR" .. msg, 0)
end

local function fmt_token(ls, token)
    if token then
        local tok
        if token == 'TK_name' or token == 'TK_string' or token == 'TK_number' then
            tok = ls.save_buf
        else
            tok = string.format("'%s'", token2str(token))
        end
        -- replace % with %%, so as not to confuse string.format() later
        return (string.gsub(tok, "%%.", function(p) return '%' .. p end))
    end
end

local function lex_error(ls, token, em, ...)
    local tok = fmt_token(ls, token)
    if tok then
        em = string.format("%s near %s", em, tok)
    end
    throw(ls.chunkname, ls.linenumber, em, ...)
end


local function parse_error(ls, token, em, ...)
    local tok = fmt_token(ls, token)
    if tok then
        em = string.format("%s instead of %s", em, tok) 
    end
    throw(ls.chunkname, ls.linenumber, em, ...)
end

local function char_isalnum(c)
    if type(c) == 'string' then
        local b = strbyte(c)
        if b >= ASCII_0 and b <= ASCII_9 then
            return true
        elseif b >= ASCII_a and b <= ASCII_z then
            return true
        elseif b >= ASCII_A and b <= ASCII_Z then
            return true
        else
            return (c == '_')
        end
    end
    return false
end

local function char_isdigit(c)
    if type(c) == 'string' then
        local b = strbyte(c)
        return b >= ASCII_0 and b <= ASCII_9
    end
    return false
end

local function char_isspace(c)
    local b = strbyte(c)
    return b >= 9 and b <= 13 or b == 32
end

local function byte(ls, n)
    local k = ls.p + n
    return strsub(ls.data, k, k)
end

local function skip(ls, n)
    ls.n = ls.n - n
    ls.p = ls.p + n
end

local function popchar(ls)
    local k = ls.p
    local c = strsub(ls.data, k, k)
    ls.p = k + 1
    ls.n = ls.n - 1
    return c
end

local function fill(ls)
    local data = ls:read_func()
    if not data then
        return END_OF_STREAM
    end
    ls.data, ls.n, ls.p = data, #data, 1
    return popchar(ls)
end

local function nextchar(ls)
    local c = ls.n > 0 and popchar(ls) or fill(ls)
    ls.current = c
    return c
end

local function savebuf(ls, c)
    ls.save_buf = ls.save_buf .. c
end

local function get_string(ls, init_skip, end_skip)
    return strsub(ls.save_buf, init_skip + 1, - (end_skip + 1))
end

local function add_comment(ls, str)
    if not ls.comment_buf then
        ls.comment_buf = ''
    end
    ls.comment_buf = ls.comment_buf .. str
end

local function get_comment(ls)
    local s = ls.comment_buf
    ls.comment_buf = ''
    return s
end

local function inclinenumber(ls)
    local old = ls.current
    -- skip `\n' or `\r'
    nextchar(ls)
    if IsNewLine[ls.current] and ls.current ~= old then
        -- skip `\n\r' or `\r\n'
        nextchar(ls)
    end
    ls.linenumber = ls.linenumber + 1
end

local function skip_sep(ls)
    local count = 0
    local s = ls.current
    assert(s == '[' or s == ']')
    savebuf(ls, s)
    nextchar(ls)
    while ls.current == '=' do
        savebuf(ls, ls.current)
        nextchar(ls)
        count = count + 1
    end
    return ls.current == s and count or (-count - 1)
end

local function build_64int(str)
    local u = str[#str - 2]
    local x = (u == 117 and uint64(0) or int64(0))
    local i = 1
    while str[i] >= ASCII_0 and str[i] <= ASCII_9 do
        x = 10 * x + (str[i] - ASCII_0)
        i = i + 1
    end
    return x
end

-- Only lower case letters are accepted.
local function byte_to_hexdigit(b)
    if b >= ASCII_0 and b <= ASCII_9 then
        return b - ASCII_0
    elseif b >= ASCII_a and b <= ASCII_f then
        return 10 + (b - ASCII_a)
    else
        return -1
    end
end

local function build_64hex(str)
    local u = str[#str - 2]
    local x = (u == 117 and uint64(0) or int64(0))
    local i = 3
    while str[i] do
        local n = byte_to_hexdigit(str[i])
        if n < 0 then break end
        x = 16 * x + n
        i = i + 1
    end
    return x
end

local function strnumdump(str)
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

local function lex_number(ls)
    local lower = string.lower
    local xp = 'e'
    local c = ls.current
    if c == '0' then
        savebuf(ls, ls.current)
        nextchar(ls)
        local xc = ls.current
        if xc == 'x' or xc == 'X' then xp = 'p' end
    end
    while char_isalnum(ls.current) or ls.current == '.' or
        ((ls.current == '-' or ls.current == '+') and lower(c) == xp) do
        c = lower(ls.current)
        savebuf(ls, c)
        nextchar(ls)
    end
    local str = ls.save_buf
    local x
    if strsub(str, -1, -1) == 'i' then
        local img = tonumber(strsub(str, 1, -2))
        if img then x = complex(0, img) end
    elseif strsub(str, -2, -1) == 'll' then
        local t = strnumdump(str)
        if t then
            x = xp == 'e' and build_64int(t) or build_64hex(t)
        end
    else
        x = tonumber(str)
    end
    if x then
        return x
    else
        lex_error(ls, 'TK_number', "malformed number")
    end
end

local function read_long_string(ls, sep, comment)
    -- skip 2nd `['
    savebuf(ls, ls.current)
    nextchar(ls)
    --if IsNewLine[ls.current] then -- string starts with a newline?
    --    inclinenumber(ls) -- skip it
    --end
    while true do
        local c = ls.current
        if c == END_OF_STREAM then
            lex_error(ls, 'TK_eof', comment and "unfinished long comment" or "unfinished long string")
        elseif c == ']' then
            if skip_sep(ls) == sep then
                -- skip 2nd `]'
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
    --return get_string(ls, 2 + sep, 2 + sep)
    return get_string(ls, 0, 0)
end

local function hex_char(c)
    if string.match(c, '^%x') then
        local b = band(strbyte(c), 15)
        if not char_isdigit(c) then b = b + 9 end
        return b
    end
end

-- this function works tightly with luacode-generator ExpressionRule:Literal
local function read_escape_char(ls)
    local c = nextchar(ls) -- Skip the '\\'.
    local esc = IsEscape[c]
    if esc then
        -- eg: convert '\n' to '\\n', which is no longer newline
        savebuf(ls, '\\')
        savebuf(ls, c)
        nextchar(ls)
    elseif c == 'x' then -- Hexadecimal escape '\xXX'.
        savebuf(ls, '\\')
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
            lex_error(ls, 'TK_string', "invalid escape sequence")
        end
        --savebuf(ls, hc)
        nextchar(ls)
    elseif c == 'z' then -- Skip whitespace.
        nextchar(ls)
        while char_isspace(ls.current) do
            if IsNewLine[ls.current] then 
                inclinenumber(ls) 
            else 
                nextchar(ls)
            end
        end
    elseif IsNewLine[c] then
        savebuf(ls, '\n')
        inclinenumber(ls)
    elseif c == '\\' then
        savebuf(ls, '\\')
        savebuf(ls, c)
        nextchar(ls)
    elseif c == '"' or c == "'" then
        savebuf(ls, c)
        nextchar(ls)
    elseif c == END_OF_STREAM then
    else
        if not char_isdigit(c) then
            lex_error(ls, 'TK_string', "invalid escape sequence")
        end
        savebuf(ls, '\\')
        savebuf(ls, c)
        local bc = band(strbyte(c), 15) -- Decimal escape '\ddd'.
        if char_isdigit(nextchar(ls)) then
            savebuf(ls, ls.current)
            bc = bc * 10 + band(strbyte(ls.current), 15)
            if char_isdigit(nextchar(ls)) then
                savebuf(ls, ls.current)
                bc = bc * 10 + band(strbyte(ls.current), 15)
                nextchar(ls)
            end
        end
        -- cannot save in the end, "\04922" should be "122" but becomes "\4922" which is invalid
        --savebuf(ls, strchar(bc))
        if bc > 255 then
            lex_error(ls, 'TK_string', "invalid escape sequence")
        end
    end
end

local function read_string(ls, delim)
    savebuf(ls, ls.current)
    nextchar(ls)
    while ls.current ~= delim do
        local c = ls.current
        if c == END_OF_STREAM then
            lex_error(ls, 'TK_eof', "unfinished string")
        elseif IsNewLine[c] then
            lex_error(ls, 'TK_string', "unfinished string")
        elseif c == '\\' then
            read_escape_char(ls)
        else
            savebuf(ls, ls.current)
            nextchar(ls)
        end
    end
    savebuf(ls, ls.current) -- skip delimiter
    nextchar(ls)
    return get_string(ls, 1, 1)
end

local function skip_line(ls)
    while not IsNewLine[ls.current] and ls.current ~= END_OF_STREAM do
        add_comment(ls, ls.current)
        nextchar(ls)
    end
end

local function llex(ls)
    ls.save_buf = ''
    if ls.newline then
        ind = ls.newline
        ls.newline = nil
        if ind ~= stack:top() then
            if ind > stack:top() then
                stack:push(ind)
                return 'TK_indent'
            end
            stack:pop()
            if stack:top() ~= ind then
                ls.indent = ind
            end
            return 'TK_dedent'
        end
    elseif ls.indent then
        if ls.indent > 0 and stack:top() == 0 then
            lex_error(ls, nil, "unaligned or dangling <indent>")
        end
        stack:pop()
        if ls.indent == stack:top() then
            ls.indent = nil
        end
        return 'TK_dedent'
    elseif ls.minus then
        ls.minus = nil
        return '-'
    end
   
    local tabs = nil
    while true do
        local current = ls.current
        
        if IsNewLine[current] then
            tabs = nil  -- if come back here, is an empty line, reset tab space tracker
            inclinenumber(ls)
            local ind = 0
            while ls.current == ' ' or ls.current == '\t' do
                if not tabs then
                    tabs = ls.current
                elseif tabs ~= ls.current then
                    lex_error(ls, nil, "indentation cannot mix tab and space")
                end
                ind = ind + 1
                nextchar(ls)
            end
            if ls.current ~= END_OF_STREAM then
                ls.newline = ind    -- prepare to handle newline
            else
                ls.newline = nil    -- reached EOF, ignore previous newline(s)
            end
        elseif current == END_OF_STREAM then
            if stack:top() > 0 then
                stack:pop()
                return 'TK_dedent'
            end
            return 'TK_eof'
        elseif current == ' ' or current == '\t' or current == '\b' or current == '\f' then
            -- skip space in between characters
            nextchar(ls)
        elseif current == '-' then
            nextchar(ls)
            if ls.current == '-' then
                -- is a comment
                ls.newline = nil  -- do not treat newline
                tabs = nil  -- or check tab space
                nextchar(ls)
                add_comment(ls, '--')
                if ls.current == '[' then
                    local sep = skip_sep(ls)
                    add_comment(ls, ls.save_buf)  -- `skip_sep' may have changed save_buf
                    ls.save_buf = ''
                    if sep >= 0 then
                        read_long_string(ls, sep, true) -- long comment
                        add_comment(ls, ls.save_buf)  -- `read_long_string' may have change save_buf
                        ls.save_buf = '' 
                    else
                        skip_line(ls)
                    end
                else
                    skip_line(ls)
                end
                return 'TK_comment', get_comment(ls)
            elseif ls.current == '>' then
                nextchar(ls)
                return 'TK_lambda'
            elseif ls.newline then
                ls.minus = true
            else
                return '-'
            end
        elseif ls.newline then
            if tabs then
                if not ls.tabs then 
                    ls.tabs = tabs
                elseif tabs ~= ls.tabs then
                    lex_error(ls, nil, "cannot mix tab and space as indentation")
                end
            end
            return 'TK_newline'
        else
            if char_isalnum(current) then
                if char_isdigit(current) then -- Numeric literal.
                    return 'TK_number', lex_number(ls)
                end
                repeat
                    savebuf(ls, ls.current)
                    nextchar(ls)
                until not char_isalnum(ls.current)
                local s = get_string(ls, 0, 0)
                -- hack for ngx.var.xxx  
                --if s == "var" and ls.current ~= ' ' and ls.current ~= '\t' then
                --   return 'TK_name', s
                --end
                local reserved = ReservedKeyword[s]
                if reserved then
                    return 'TK_' .. s
                end
                return 'TK_name', s
            elseif current == '@' then
                nextchar(ls)
                return 'TK_name', 'self'
            elseif current == '[' then
                local sep = skip_sep(ls)
                if sep >= 0 then
                    local str = read_long_string(ls, sep)
                    return 'TK_longstring', str
                elseif sep == -1 then
                    return '['
                else
                    lex_error(ls, 'TK_longstring', "delimiter error")
                end
            elseif current == '=' then
                nextchar(ls)
                if ls.current ~= '=' then return '=' else nextchar(ls); return 'TK_eq' end
            elseif current == '<' then
                nextchar(ls)
                if ls.current ~= '=' then return '<' else nextchar(ls); return 'TK_le' end
            elseif current == '>' then
                nextchar(ls)
                if ls.current ~= '=' then return '>' else nextchar(ls); return 'TK_ge' end
            elseif current == '~' then
                nextchar(ls)
                if ls.current == '=' then 
                    nextchar(ls)
                    return 'TK_ne'
                elseif ls.current == '>' then 
                    nextchar(ls)
                    return 'TK_curry'
                end     
                return '~'
            elseif current == ':' then
                nextchar(ls)
                if ls.current ~= ':' then return ':' else nextchar(ls); return 'TK_label' end
            elseif current == '"' or current == "'" then
                local str = read_string(ls, current)
                return 'TK_string', str
            elseif current == '.' then
                savebuf(ls, ls.current)
                nextchar(ls)
                if ls.current == '.' then
                    nextchar(ls)
                    if ls.current == '.' then
                        nextchar(ls)
                        return 'TK_dots' -- ...
                    end
                    return 'TK_concat' -- ..
                elseif not char_isdigit(ls.current) then
                    return '.'
                else
                    return 'TK_number', lex_number(ls)
                end
            else
                nextchar(ls)
                return current -- Single-char tokens (+ - / ...).
            end
        end
    end
end

local function do_lex(ls)
    local token, value
    while true do
        token, value = llex(ls)
        --if token == 'TK_newline' then
        --    if ls.want_nl then break end
        --else
        if token ~= 'TK_comment' then 
            break
        end
    end
    return token, value 
end


local Lexer = {
    token2str = token2str
    , error = parse_error
}

--[[
function Lexer.nl(ls, bool)
    ls.want_nl = bool
end
]]

function Lexer.next(ls)
    ls.lastline = ls.linenumber
    if ls.tklookahead == 'TK_eof' then -- No lookahead token?
        ls.token, ls.tokenval = do_lex(ls)
    else
        ls.token, ls.tokenval = ls.tklookahead, ls.tklookaheadval
        ls.tklookahead = 'TK_eof'
    end
end

function Lexer.lookahead(ls)
    if ls.tklookahead == 'TK_eof' then
        ls.tklookahead, ls.tklookaheadval = do_lex(ls)
    end
    return ls.tklookahead, ls.tklookaheadval
end


local LexerClass = { __index = Lexer }

local function lex_setup(read_func, chunkname)
    local header = false
    local ls = {
        n = 0,
        tklookahead = 'TK_eof', -- No look-ahead token.
        linenumber = 1,
        lastline = 1,
        read_func = read_func,
        chunkname = chunkname,
        tabs = nil
        --want_nl = true
    }
    stack:push(0)
    nextchar(ls)
    if ls.current == '\xef' and ls.n >= 2 and
        byte(ls, 0) == '\xbb' and byte(ls, 1) == '\xbf' then -- Skip UTF-8 BOM (if buffered).
        ls.n = ls.n - 2
        ls.p = ls.p + 2
        nextchar(ls)
        header = true
    end
    if ls.current == '#' then
        repeat
            nextchar(ls)
            if ls.current == END_OF_STREAM then return ls end
        until IsNewLine[ls.current]
        inclinenumber(ls)
        header = true
    end
    return setmetatable(ls, LexerClass)
end

return lex_setup
