--
-- Generated from parse.lt
--

local ast = require("lua.ast")
local ty = require("lua.type")
local operator = require("lua.operator")
local reserved = require("lua.reserved")
local Stmt = ast.Stmt
local Expr = ast.Expr
local Keyword = reserved.Keyword
local LJ_52 = false
local EndOfChunk = {TK_dedent = true, TK_else = true, TK_until = true, TK_eof = true}
local EndOfFunction = {["}"] = true, [")"] = true, [";"] = true, [","] = true}
local NewLine = {TK_newline = true}
local Kind = {Expr = 1, Var = 3, Property = 4, Index = 5, Call = 6}
local stmted
local is_keyword = function(ls)
    local str = ls.tostr(ls.token)
    if Keyword[str] then
        return str
    end
end
local err_warn = function(ls, em)
    ls.error(ls, 2, "%s", em)
end
local err_syntax = function(ls, em)
    ls.error(ls, 10, "%s", em)
end
local as_val = function(ls)
    if ls.value then
        return "'" .. ls.value .. "'"
    end
end
local err_instead = function(ls, severe, em, ...)
    local msg = string.format(em, ...)
    ls.error(ls, severe, "%s instead of %s", msg, as_val(ls) or ls.astext(ls.token))
end
local err_expect = function(ls, token)
    err_instead(ls, 10, "%s expected", ls.astext(token))
end
local err_symbol = function(ls)
    local sym = ls.tostr(ls.token)
    local replace = {["end"] = "<dedent>", ["local"] = "`var`", ["function"] = "\\...->", ["elseif"] = "`else if`", ["repeat"] = "`do`"}
    local rep = replace[sym]
    if rep then
        ls.error(ls, 7, "use %s instead of '%s'", rep, sym)
    else
        ls.error(ls, 10, "unexpected %s", as_val(ls) or ls.astext(ls.token))
    end
end
local lex_opt = function(ls, tok)
    if ls.token == tok then
        ls.step()
        return true
    end
    return false
end
local lex_check = function(ls, tok)
    if ls.token ~= tok then
        err_expect(ls, tok)
    end
    ls.step()
end
local lex_match = function(ls, what, who, line)
    if not lex_opt(ls, what) then
        if line == ls.line then
            err_expect(ls, what)
        else
            err_instead(ls, 10, "%s expected to match %s at line %d", ls.astext(what), ls.astext(who), line)
        end
        return false
    end
    return true
end
local lex_str = function(ls)
    local s
    if ls.token ~= "TK_name" and (LJ_52 or ls.token ~= "TK_goto") then
        err_expect(ls, "TK_name")
        s = ls.tostr(ls.token)
    else
        s = ls.value
    end
    ls.step()
    return s
end
local lex_indent = function(ls)
    if NewLine[ls.token] and ls.next() == "TK_indent" then
        lex_opt(ls, "TK_newline")
        ls.step()
        return true
    end
    return false
end
local lex_dedent = function(ls)
    if ls.token == "TK_dedent" or NewLine[ls.token] and ls.next() == "TK_dedent" then
        lex_opt(ls, "TK_newline")
        ls.step()
        return true
    end
    return false
end
local lex_opt_dent = function(ls, dented)
    if not dented then
        dented = lex_indent(ls)
    else
        dented = not lex_dedent(ls)
    end
    lex_opt(ls, "TK_newline")
    return dented
end
local parse_type, type_unary, type_binary, type_basic
local type_tbl = function(ls)
    local line = ls.line
    ls.step()
    local kvs = {}
    local dented = false
    while ls.token ~= "}" do
        dented = lex_opt_dent(ls, dented)
        if not dented and ls.token == "TK_dedent" then
            err_symbol(ls)
            ls.step()
        end
        if ls.token == "}" then
            break
        end
        local val = parse_type(ls)
        local key
        if ls.token == ":" then
            ls.step()
            key = val
            val = parse_type(ls)
        end
        if key then
            for i = 1, #kvs do
                local arr = kvs[i]
                if ast.same(arr[2], key) then
                    ls.error(ls, 10, "similar key type at position %i and %i in table type annotation", i, (#kvs + 1))
                end
            end
        else
            if not val then
                err_instead(ls, 10, "type expected in table type annotation")
            else
                for i = 1, #kvs do
                    local arr = kvs[i]
                    if not arr[2] and ast.same(arr[1], val) then
                        ls.error(ls, 10, "similar value type at position %i and %i in table type annotation", i, (#kvs + 1))
                    end
                end
            end
        end
        kvs[#kvs + 1] = {val, key}
        dented = lex_opt_dent(ls, dented)
        if not lex_opt(ls, ",") then
            break
        end
    end
    if dented and not lex_dedent(ls) then
        err_instead(ls, 10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
    end
    lex_match(ls, "}", "{", line)
    return ty.tbl(kvs)
end
local type_list = function(isparam, ls)
    local list = {}
    if not (isparam and ls.token == "/" or ls.token == "]") then
        repeat
            if ls.token == "..." then
                ls.step()
                list[#list + 1] = parse_type(ls, true)
                break
            else
                list[#list + 1] = parse_type(ls)
            end
        until not lex_opt(ls, ",")
    end
    return list
end
local type_func = function(ls)
    local line = ls.line
    ls.step()
    local params = type_list(true, ls)
    local returns
    if ls.token == "/" then
        ls.step()
        returns = type_list(false, ls)
    end
    lex_match(ls, "]", "[", line)
    return ty.func(params, returns)
end
local type_prefix = function(ls)
    local typ
    if ls.token == "TK_name" then
        typ = ty.custom(ls.value)
        ls.step()
    elseif ls.token == "(" then
        local line = ls.line
        ls.step()
        typ = ty.bracket(parse_type(ls))
        lex_match(ls, ")", "(", line)
    else
        return typ
    end
    while ls.token == "." do
        ls.step()
        if ls.token ~= "TK_name" then
            break
        end
        typ = ty.index(typ, ls.value)
        ls.step()
    end
    return typ
end
type_basic = function(ls)
    local typ
    local val
    if ls.token == "TK_name" then
        val = ls.value
    end
    if val == "any" then
        typ = ty.any()
    elseif val == "num" or val == "number" then
        typ = ty.num()
        if val == "number" then
            err_warn("use `num` instead of `number`")
        end
    elseif val == "str" or val == "string" then
        typ = ty.str()
        if val == "string" then
            err_warn("use `str` instead of `string`")
        end
    elseif val == "bool" or val == "boolean" then
        typ = ty.bool()
        if val == "boolean" then
            err_warn("use `bool` instead of `boolean`")
        end
    else
        if ls.token == "TK_nil" then
            typ = ty["nil"]()
        else
            if ls.token == "[" then
                return type_func(ls)
            end
            if ls.token == "{" then
                return type_tbl(ls)
            end
            return type_prefix(ls)
        end
    end
    ls.step()
    return typ
end
type_unary = function(ls)
    local tk = ls.token
    if tk == "!" then
        ls.step()
        local t = type_binary(ls, operator.unary_priority)
        return ty["not"](t)
    else
        return type_basic(ls)
    end
end
type_binary = function(ls, limit)
    local l = type_unary(ls)
    local op = ls.token
    while operator.is_typeop(op) and operator.left_priority(op) > limit do
        ls.step()
        local r, nextop = type_binary(ls, operator.right_priority(op))
        if op == "?" then
            l = ty["or"](l, ty["nil"]())
        elseif op == "|" then
            l = ty["or"](l, r)
        elseif op == "&" then
            l = ty["and"](l, r)
        else
            ls.error(ls, 10, "unexpected %s", as_val(ls) or ls.astext(ls.token))
            break
        end
        op = nextop
    end
    return l, op
end
parse_type = function(ls, varargs)
    local typ = type_binary(ls, 0)
    if typ and varargs then
        return ty.varargs(typ)
    end
    return typ
end
local expr_primary, expr, expr_unop, expr_binop, expr_simple, expr_list, expr_table
local parse_body, parse_args, parse_block
local expr_bracket = function(ls)
    ls.step()
    local v = expr(ls)
    lex_check(ls, "]")
    return v
end
expr_table = function(ls)
    local line = ls.line
    local kvs = {}
    local dented = false
    lex_check(ls, "{")
    while ls.token ~= "}" do
        dented = lex_opt_dent(ls, dented)
        if not dented and ls.token == "TK_dedent" then
            err_symbol(ls)
            ls.step()
        end
        if ls.token == "}" then
            break
        end
        local key
        if ls.token == "[" then
            key = expr_bracket(ls)
            lex_check(ls, "=")
        elseif ls.next() == "=" then
            if ls.token == "TK_name" then
                local name = lex_str(ls)
                key = Expr.string(name)
            elseif ls.token == "TK_string" then
                key = Expr.string(ls.value)
                ls.step()
            else
                local name = is_keyword(ls)
                if name then
                    key = Expr.string(name)
                else
                    err_syntax(ls, "invalid table key " .. as_val(ls) or ls.astext(ls.token))
                end
                ls.step()
            end
            lex_check(ls, "=")
        end
        local val = expr(ls)
        if key then
            for i = 1, #kvs do
                local arr = kvs[i]
                if ast.same(arr[2], key) then
                    err_warn(ls, "duplicate key at position " .. i .. " and " .. #kvs + 1 .. " in table")
                end
            end
        end
        kvs[#kvs + 1] = {val, key}
        dented = lex_opt_dent(ls, dented)
        if ls.token == ";" then
            err_instead(ls, 3, "use `,`")
        end
        if not lex_opt(ls, ",") and not lex_opt(ls, ";") then
            break
        end
    end
    if dented and not lex_dedent(ls) then
        err_instead(ls, 10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
    end
    lex_match(ls, "}", "{", line)
    return Expr.table(kvs, line)
end
local expr_function = function(ls)
    local line = ls.line
    if ls.token == "\\" then
        ls.step()
    end
    local curry, params, body, varargs = parse_body(ls, line)
    local lambda = Expr["function"](params, body, varargs, line)
    if curry then
        local cargs = {Expr.number(#params), lambda}
        return Expr.call(Expr.id("curry", line), cargs, line)
    end
    return lambda
end
expr_simple = function(ls)
    local tk, val = ls.token, ls.value
    local line = ls.line
    local e
    if tk == "TK_number" then
        e = Expr.number(val, line)
    elseif tk == "TK_string" then
        e = Expr.string(val, false, line)
    elseif tk == "TK_longstring" then
        e = Expr.string(val, true, line)
    elseif tk == "TK_nil" then
        e = Expr.null(line)
    elseif tk == "TK_true" then
        e = Expr.bool(true, line)
    elseif tk == "TK_false" then
        e = Expr.bool(false, line)
    elseif tk == "..." then
        e = Expr.vararg(line)
    elseif tk == "{" then
        return expr_table(ls)
    elseif tk == "\\" or tk == "->" or tk == "~>" then
        return expr_function(ls)
    else
        return expr_primary(ls)
    end
    ls.step()
    return e
end
expr_list = function(ls, nmax)
    local exps = {}
    exps[1] = expr(ls)
    while ls.token == "," do
        ls.step()
        exps[#exps + 1] = expr(ls)
    end
    local n = #exps
    if nmax and n > nmax then
        err_warn(ls, "assigning " .. n .. " values to " .. nmax .. " variable(s)")
    end
    return exps
end
expr_unop = function(ls)
    local tk = ls.token
    if tk == "TK_not" or tk == "-" or tk == "#" then
        local line = ls.line
        ls.step()
        local v = expr_binop(ls, operator.unary_priority)
        return Expr.unary(ls.tostr(tk), v, line)
    else
        return expr_simple(ls)
    end
end
expr_binop = function(ls, limit)
    local v = expr_unop(ls)
    local op = ls.tostr(ls.token)
    while operator.is_binop(op) and operator.left_priority(op) > limit do
        local line = ls.line
        ls.step()
        local v2, nextop = expr_binop(ls, operator.right_priority(op))
        v = Expr.binary(op, v, v2, line)
        op = nextop
    end
    return v, op
end
expr = function(ls)
    return expr_binop(ls, 0)
end
expr_primary = function(ls)
    local v, vk
    if ls.token == "(" then
        local line = ls.line
        ls.step()
        vk, v = Kind.Expr, ast.bracket(expr(ls))
        lex_match(ls, ")", "(", line)
    else
        v, vk = Expr.id(lex_str(ls), ls.line), Kind.Var
    end
    local val, key
    while true do
        local line = ls.line
        if ls.token == "." then
            ls.step()
            val = v
            local kw = is_keyword(ls)
            if kw then
                ls.step()
                key = Expr.string(kw)
                vk, v = Kind.Index, Expr.index(val, key)
            else
                key = lex_str(ls)
                vk, v = Kind.Property, Expr.property(val, key)
            end
        elseif ls.token == "[" then
            key = expr_bracket(ls)
            val = v
            vk, v = Kind.Index, Expr.index(val, key)
        elseif ls.token == "(" then
            local args = parse_args(ls)
            vk, v = Kind.Call, Expr.call(v, args, line)
        else
            break
        end
    end
    return v, vk
end
local parse_return = function(ls, line)
    ls.step()
    local exps
    if EndOfChunk[ls.token] or NewLine[ls.token] or EndOfFunction[ls.token] then
        exps = {}
    else
        exps = expr_list(ls)
    end
    return Stmt["return"](exps, line)
end
local parse_for_num = function(ls, idxname, line)
    lex_check(ls, "=")
    local first = expr(ls)
    lex_check(ls, ",")
    local last = expr(ls)
    local step
    if lex_opt(ls, ",") then
        step = expr(ls)
    end
    local var = Expr.id(idxname, line)
    local body = parse_block(ls, line, "TK_for")
    return Stmt.fornum(var, first, last, step, body, line)
end
local parse_for_in = function(ls, idxname)
    local vars = {Expr.id(idxname, ls.line)}
    while lex_opt(ls, ",") do
        vars[#vars + 1] = Expr.id(lex_str(ls), ls.line)
    end
    lex_check(ls, "TK_in")
    local line = ls.line
    local exps = expr_list(ls)
    local body = parse_block(ls, line, "TK_for")
    return Stmt.forin(vars, exps, body, line)
end
local parse_for = function(ls, line)
    ls.step()
    local idxname = lex_str(ls)
    local stmt
    if ls.token == "=" then
        stmt = parse_for_num(ls, idxname, line)
    elseif ls.token == "," or ls.token == "TK_in" then
        stmt = parse_for_in(ls, idxname)
    else
        err_instead(ls, 10, "`=` or `in` expected")
    end
    return stmt
end
parse_args = function(ls)
    local line = ls.line
    lex_check(ls, "(")
    if not LJ_52 and line ~= ls.prevline then
        err_warn(ls, "ambiguous syntax (function call x new statement)")
    end
    local dented = false
    local args = {}
    while ls.token ~= ")" do
        dented = lex_opt_dent(ls, dented)
        if not dented and ls.token == "TK_dedent" then
            err_symbol(ls)
            ls.step()
        end
        if ls.token == ")" then
            break
        end
        args[#args + 1] = expr(ls)
        dented = lex_opt_dent(ls, dented)
        if not lex_opt(ls, ",") then
            break
        end
    end
    if dented and not lex_dedent(ls) then
        err_instead(ls, 10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
    end
    lex_match(ls, ")", "(", line)
    return args
end
local parse_assignment
parse_assignment = function(ls, lhs, v, vk)
    local line = ls.line
    if vk ~= Kind.Var and vk ~= Kind.Property and vk ~= Kind.Index then
        err_symbol(ls)
    end
    lhs[#lhs + 1] = v
    if lex_opt(ls, ",") then
        local n_var, n_vk = expr_primary(ls)
        return parse_assignment(ls, lhs, n_var, n_vk)
    else
        lex_check(ls, "=")
        local exps = expr_list(ls, #lhs)
        return Stmt.assign(lhs, exps, line)
    end
end
local parse_call_assign = function(ls)
    local v, vk = expr_primary(ls)
    if vk == Kind.Call then
        return Stmt.expression(v, ls.line)
    else
        local lhs = {}
        return parse_assignment(ls, lhs, v, vk)
    end
end
local parse_var = function(ls)
    local line = ls.line
    local names = {}
    repeat
        local name = lex_str(ls)
        local typ = parse_type(ls)
        names[#names + 1] = name
    until not lex_opt(ls, ",")
    local rhs = {}
    if lex_opt(ls, "=") then
        rhs = expr_list(ls, #names)
    end
    local lhs = {}
    for _, name in ipairs(names) do
        lhs[#lhs + 1] = Expr.id(name, line)
    end
    return Stmt["local"](lhs, rhs, line)
end
local parse_while = function(ls, line)
    ls.step()
    local cond = expr(ls)
    local body = parse_block(ls, line, "TK_while")
    return Stmt["while"](cond, body, line)
end
local parse_then = function(ls, tests, line)
    ls.step()
    tests[#tests + 1] = expr(ls)
    if ls.token == "TK_then" then
        err_warn(ls, "`then` is not needed")
        ls.step()
    end
    return parse_block(ls, line, "TK_if")
end
local parse_if = function(ls, line)
    local tests, blocks = {}, {}
    blocks[#blocks + 1] = parse_then(ls, tests, line)
    local else_branch
    while ls.token == "TK_else" or NewLine[ls.token] and ls.next() == "TK_else" do
        lex_opt(ls, "TK_newline")
        ls.step()
        if ls.token == "TK_if" then
            blocks[#blocks + 1] = parse_then(ls, tests, line)
        else
            else_branch = parse_block(ls, ls.line, "TK_else")
            break
        end
    end
    return Stmt["if"](tests, blocks, else_branch, line)
end
local parse_do = function(ls, line)
    ls.step()
    local body = parse_block(ls, line, "TK_do")
    if lex_opt(ls, "TK_until") then
        local cond = expr(ls)
        return Stmt["repeat"](cond, body, line)
    end
    return Stmt["do"](body, line)
end
local parse_break = function(ls, line)
    ls.step()
    return Stmt["break"](line)
end
local parse_label = function(ls, line)
    ls.step()
    local name = lex_str(ls)
    lex_check(ls, "::")
    return Stmt.label(name, line)
end
local parse_goto = function(ls, line)
    local name = lex_str(ls)
    return Stmt["goto"](name, line)
end
local parse_stmt
parse_stmt = function(ls)
    local line = ls.line
    local stmt
    if ls.token == "TK_if" then
        stmt = parse_if(ls, line)
    elseif ls.token == "TK_for" then
        stmt = parse_for(ls, line)
    elseif ls.token == "TK_while" then
        stmt = parse_while(ls, line)
    elseif ls.token == "TK_do" then
        stmt = parse_do(ls, line)
    elseif ls.token == "TK_repeat" then
        err_symbol(ls)
        stmt = parse_do(ls, line)
    elseif ls.token == "\\" or ls.token == "->" or ls.token == "~>" then
        err_syntax(ls, "lambda must either be assigned or immediately invoked")
        stmt = expr_function(ls)
    elseif ls.token == "TK_name" and ls.value == "var" then
        ls.step()
        stmt = parse_var(ls, line)
    elseif ls.token == "TK_local" then
        err_symbol(ls)
        ls.step()
        stmt = parse_var(ls, line)
    elseif ls.token == "TK_return" then
        stmt = parse_return(ls, line)
        return stmt, true
    elseif ls.token == "TK_break" then
        stmt = parse_break(ls, line)
        return stmt, not LJ_52
    elseif ls.token == "::" then
        stmt = parse_label(ls, line)
    elseif ls.token == "TK_goto" then
        if LJ_52 or ls.next() == "TK_name" then
            ls.step()
            stmt = parse_goto(ls, line)
        end
    end
    if not stmt then
        stmt = parse_call_assign(ls)
    end
    return stmt, false
end
local parse_stmts = function(ls)
    local skip_ends = function()
        while ls.token == ";" or ls.token == "TK_end" do
            err_symbol(ls)
            ls.step()
        end
        lex_opt(ls, "TK_newline")
    end
    local firstline = ls.line
    local stmt, islast = nil, false
    local body = {}
    while not islast and not EndOfChunk[ls.token] do
        stmted = ls.line
        skip_ends()
        stmt, islast = parse_stmt(ls)
        body[#body + 1] = stmt
        skip_ends()
        if stmted == ls.line then
            if ls.token ~= "TK_eof" and ls.token ~= "TK_dedent" and ls.next() ~= "TK_eof" then
                err_instead(ls, 5, "statement should end. %s expected", ls.astext("TK_newline"))
            end
        end
    end
    return body, firstline, ls.line
end
parse_block = function(ls, line, match_token)
    local body = {}
    if lex_indent(ls) then
        body = parse_stmts(ls)
        if not lex_dedent(ls) then
            err_instead(ls, 10, "%s expected to end %s at line %d", ls.astext("TK_dedent"), ls.astext(match_token), line)
        end
    else
        if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
            body[1] = parse_stmt(ls)
        end
        if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
            err_instead(ls, 10, "statement should end near %s. %s expected", ls.astext(match_token), ls.astext("TK_newline"))
        elseif EndOfFunction[ls.token] then
            lex_opt(ls, ";")
        end
    end
    return body
end
local parse_params = function(ls)
    local params = {}
    local rettyp = {}
    local varargs = false
    if ls.token ~= "->" and ls.token ~= "~>" then
        repeat
            if ls.token == "TK_name" or not LJ_52 and ls.token == "TK_goto" then
                local name = lex_str(ls)
                local typ = parse_type(ls)
                params[#params + 1] = Expr.id(name, ls.line)
            elseif ls.token == "..." then
                ls.step()
                varargs = true
                local typ = parse_type(ls, true)
                params[#params + 1] = Expr.vararg(ls.line)
                if ls.next() ~= "/" then
                    break
                end
            elseif ls.token == "/" then
                ls.step()
                repeat
                    rettyp[#rettyp + 1] = parse_type(ls)
                until not lex_opt(ls, ",")
                break
            else
                err_instead(ls, 10, "parameter expected for `->`")
            end
        until not lex_opt(ls, ",") and ls.token ~= "/"
    end
    if ls.token == "->" then
        ls.step()
        return false, params, varargs
    elseif ls.token == "~>" then
        ls.step()
        if varargs then
            err_syntax(ls, "cannot curry variadic parameters with `~>`")
        end
        if #params < 2 then
            err_syntax(ls, "at least 2 parameters needed with `~>`")
        end
        return true, params, varargs
    end
    err_expect(ls, "->")
end
parse_body = function(ls, line)
    local curry, params, varargs = parse_params(ls)
    local body = parse_block(ls, line, "->")
    return curry, params, body, varargs
end
local parse = function(ls)
    ls.step()
    lex_opt(ls, "TK_newline")
    local chunk = parse_stmts(ls)
    if ls.token ~= "TK_eof" then
        err_warn(ls, "code should end. unexpected extra " .. ls.astext(ls.token))
    end
    return chunk
end
return parse