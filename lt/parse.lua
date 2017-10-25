--
-- Generated from parse.lt
--

local ast = require("lt.ast")
local operator = require("lt.operator")
local reserved = require("lt.reserved")
local scoping = require("lt.scope")
local scope
local Keyword = reserved.Keyword
local LJ_52 = false
local EndOfChunk = {TK_dedent = true, TK_else = true, TK_until = true, TK_eof = true}
local EndOfFunction = {["}"] = true, [")"] = true, [";"] = true, [","] = true}
local NewLine = {TK_newline = true}
local Kind = {Expr = 1, Var = 3, Field = 4, Index = 5, Call = 6}
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
    end
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
local declare_var = function(ls, name, vtype)
    if name == "@" then
        name = "self"
    end
    scope.declare(name, vtype, ls.line)
    return name
end
local expr_primary, expr, expr_unop, expr_binop, expr_simple, expr_list, expr_table
local parse_body, parse_args, parse_block, parse_opt_chunk
local var_name = function(ls)
    local name = lex_str(ls)
    local vk = Kind.Var
    if name == "@" then
        name = "self"
    end
    if scope.declared(name) == 0 then
        err_warn(ls, "undeclared identifier `" .. name .. "`")
    end
    return ast.identifier(name), vk
end
local expr_field = function(ls, v)
    ls.step()
    local key = is_keyword(ls)
    if key then
        ls.step()
        return ast.expr_index(v, ast.literal(key))
    end
    key = lex_str(ls)
    return ast.expr_property(v, key), v, key
end
local expr_bracket = function(fn, ls)
    ls.step()
    local v = expr(fn, ls)
    lex_check(ls, "]")
    return v
end
expr_table = function(fn, ls)
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
            key = expr_bracket(fn, ls)
            lex_check(ls, "=")
        elseif ls.next() == "=" then
            if ls.token == "TK_name" then
                local name = lex_str(ls)
                key = ast.literal(name)
            elseif ls.token == "TK_string" then
                key = ast.literal(ls.value)
                ls.step()
            else
                local name = is_keyword(ls)
                if name then
                    key = ast.literal(name)
                    ls.step()
                end
            end
            lex_check(ls, "=")
        end
        local val = expr(fn, ls)
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
            err_instead(ls, 3, "use %s", ls.astext(","))
        end
        if not lex_opt(ls, ",") and not lex_opt(ls, ";") then
            break
        end
    end
    if dented and not lex_dedent(ls) then
        err_instead(ls, 10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
    end
    lex_match(ls, "}", "{", line)
    return ast.expr_table(kvs, line)
end
local expr_function = function(fn, ls)
    local line = ls.line
    if ls.token == "\\" then
        ls.step()
    end
    local curry, args, body, varargs = parse_body(fn, ls, line)
    local lambda = ast.expr_function(args, body, varargs)
    if curry then
        if scope.declared("curry") == 0 then
            err_warn(ls, "require('lib.curry') is needed to use `~>`")
        end
        local cargs = {ast.literal(#args), lambda}
        return ast.expr_function_call(ast.identifier("curry"), cargs, line)
    end
    return lambda
end
expr_simple = function(fn, ls)
    local tk, val = ls.token, ls.value
    local e
    if tk == "TK_number" then
        e = ast.numberliteral(val)
    elseif tk == "TK_string" then
        e = ast.literal(val)
    elseif tk == "TK_longstring" then
        e = ast.longstrliteral(val)
    elseif tk == "TK_nil" then
        e = ast.literal(nil)
    elseif tk == "TK_true" then
        e = ast.literal(true)
    elseif tk == "TK_false" then
        e = ast.literal(false)
    elseif tk == "..." then
        if not fn.varargs then
            err_syntax(ls, "cannot use `...` in a function without variable arguments")
        end
        e = ast.expr_vararg()
    elseif tk == "{" then
        return expr_table(fn, ls)
    elseif tk == "\\" or tk == "->" or tk == "~>" then
        return expr_function(fn, ls)
    else
        return expr_primary(fn, ls)
    end
    ls.step()
    return e
end
expr_list = function(fn, ls, nmax)
    local exps = {}
    exps[1] = expr(fn, ls)
    while ls.token == "," do
        ls.step()
        exps[#exps + 1] = expr(fn, ls)
    end
    local n = #exps
    if nmax and n > nmax then
        err_warn(ls, "assigning " .. n .. " values to " .. nmax .. " variable(s)")
    end
    return exps
end
expr_unop = function(fn, ls)
    local tk = ls.token
    if tk == "TK_not" or tk == "-" or tk == "#" then
        local line = ls.line
        ls.step()
        local v = expr_binop(fn, ls, operator.unary_priority)
        return ast.expr_unop(ls.tostr(tk), v, line)
    else
        return expr_simple(fn, ls)
    end
end
expr_binop = function(fn, ls, limit)
    local v = expr_unop(fn, ls)
    local op = ls.tostr(ls.token)
    while operator.is_binop(op) and operator.left_priority(op) > limit do
        local line = ls.line
        ls.step()
        local v2, nextop = expr_binop(fn, ls, operator.right_priority(op))
        v = ast.expr_binop(op, v, v2, line)
        op = nextop
    end
    return v, op
end
expr = function(fn, ls)
    return expr_binop(fn, ls, 0)
end
expr_primary = function(fn, ls)
    local v, vk
    if ls.token == "(" then
        local line = ls.line
        ls.step()
        vk, v = Kind.Expr, ast.expr_brackets(expr(fn, ls))
        lex_match(ls, ")", "(", line)
    else
        v, vk = var_name(ls)
    end
    local val, key
    while true do
        local line = ls.line
        if ls.token == "." then
            vk, v, val, key = Kind.Field, expr_field(ls, v)
        elseif ls.token == "[" then
            key = expr_bracket(fn, ls)
            val = v
            vk, v = Kind.Index, ast.expr_index(val, key)
        elseif ls.token == "(" then
            local args, self1 = parse_args(fn, ls)
            if self1 and (vk == Kind.Field or vk == Kind.Index) then
                if vk == Kind.Field then
                    vk, v = Kind.Call, ast.expr_method_call(val, key, args, line)
                elseif vk == Kind.Index then
                    local nm = "_0"
                    local obj = ast.identifier(nm)
                    table.insert(args, 1, obj)
                    local body = {ast.local_decl({obj}, {val}, line), ast.return_stmt({ast.expr_function_call(ast.expr_index(obj, key), args, line)}, line)}
                    local lambda = ast.expr_function({}, body, false)
                    vk, v = Kind.Call, ast.expr_function_call(lambda, {}, line)
                end
            else
                vk, v = Kind.Call, ast.expr_function_call(v, args, line)
            end
        else
            break
        end
    end
    return v, vk
end
local parse_return = function(fn, ls, line)
    ls.step()
    ast.has_return = true
    local exps
    if EndOfChunk[ls.token] or NewLine[ls.token] or EndOfFunction[ls.token] then
        exps = {}
    else
        exps = expr_list(fn, ls)
    end
    return ast.return_stmt(exps, line)
end
local parse_for_num = function(fn, ls, varname, line)
    lex_check(ls, "=")
    local init = expr(fn, ls)
    lex_check(ls, ",")
    local last = expr(fn, ls)
    local step
    if lex_opt(ls, ",") then
        step = expr(fn, ls)
    else
        step = ast.literal(1)
    end
    scope.enter_block(fn)
    local name = declare_var(ls, varname, nil)
    local v = ast.identifier(name)
    local body = parse_block(fn, ls, line, "TK_for")
    scope.leave_block(fn)
    return ast.for_stmt(v, init, last, step, body, line, ls.line)
end
local parse_for_iter = function(fn, ls, indexname)
    scope.enter_block(fn)
    local name = declare_var(ls, indexname, nil)
    local vars = {ast.identifier(name)}
    while lex_opt(ls, ",") do
        name = lex_str(ls)
        name = declare_var(ls, name, nil)
        vars[#vars + 1] = ast.identifier(name)
    end
    lex_check(ls, "TK_in")
    local line = ls.line
    local exps = expr_list(fn, ls)
    local body = parse_block(fn, ls, line, "TK_for")
    scope.leave_block(fn)
    return ast.for_iter_stmt(vars, exps, body, line, ls.line)
end
local parse_for = function(fn, ls, line)
    ls.step()
    scope.enter_block(fn, true)
    local varname = lex_str(ls)
    local stmt
    if ls.token == "=" then
        stmt = parse_for_num(fn, ls, varname, line)
    elseif ls.token == "," or ls.token == "TK_in" then
        stmt = parse_for_iter(fn, ls, varname)
    else
        err_instead(ls, 10, "%s expected", "`=` or `in`")
    end
    scope.leave_block(fn)
    return stmt
end
parse_args = function(fn, ls)
    local line = ls.line
    lex_check(ls, "(")
    if not LJ_52 and line ~= ls.prevline then
        err_warn(ls, "ambiguous syntax (function call x new statement)")
    end
    local dented = false
    local self1 = false
    local args, n = {}, 1
    while ls.token ~= ")" do
        dented = lex_opt_dent(ls, dented)
        if not dented and ls.token == "TK_dedent" then
            err_symbol(ls)
            ls.step()
        end
        if ls.token == ")" then
            break
        end
        if n == 1 and ls.token == "TK_name" and ls.value == "@" then
            self1 = true
            ls.step()
        else
            args[#args + 1] = expr(fn, ls)
        end
        n = n + 1
        dented = lex_opt_dent(ls, dented)
        if not lex_opt(ls, ",") then
            break
        end
    end
    if dented and not lex_dedent(ls) then
        err_instead(ls, 10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
    end
    lex_match(ls, ")", "(", line)
    return args, self1
end
local parse_assignment
parse_assignment = function(fn, ls, vlist, v, vk)
    local line = ls.line
    if vk ~= Kind.Var and vk ~= Kind.Field and vk ~= Kind.Index then
        err_symbol(ls)
    end
    vlist[#vlist + 1] = v
    if lex_opt(ls, ",") then
        local n_var, n_vk = expr_primary(fn, ls)
        return parse_assignment(fn, ls, vlist, n_var, n_vk)
    else
        lex_check(ls, "=")
        local exps = expr_list(fn, ls, #vlist)
        return ast.assignment_expr(vlist, exps, line)
    end
end
local parse_call_assign = function(fn, ls)
    local v, vk = expr_primary(fn, ls)
    if vk == Kind.Call then
        return ast.new_statement_expr(v, ls.line)
    else
        local vlist = {}
        return parse_assignment(fn, ls, vlist, v, vk)
    end
end
local parse_var = function(fn, ls)
    local line = ls.line
    local lhs = {}
    repeat
        local name = lex_str(ls)
        name = declare_var(ls, name, nil)
        lhs[#lhs + 1] = ast.identifier(name)
    until not lex_opt(ls, ",")
    local rhs
    if lex_opt(ls, "=") then
        rhs = expr_list(fn, ls, #lhs)
    else
        rhs = {}
    end
    return ast.local_decl(lhs, rhs, line)
end
local parse_while = function(fn, ls, line)
    ls.step()
    local cond = expr(fn, ls)
    scope.enter_block(fn, true)
    local body = parse_block(fn, ls, line, "TK_while")
    scope.leave_block(fn)
    local lastline = ls.line
    return ast.while_stmt(cond, body, line, lastline)
end
local parse_then = function(fn, ls, tests, line)
    ls.step()
    tests[#tests + 1] = expr(fn, ls)
    if ls.token == "TK_then" then
        err_warn(ls, "`then` is not needed")
        ls.step()
    end
    return parse_block(fn, ls, line, "TK_if")
end
local parse_if = function(fn, ls, line)
    local tests, blocks = {}, {}
    blocks[#blocks + 1] = parse_then(fn, ls, tests, line)
    local else_branch
    while ls.token == "TK_else" or NewLine[ls.token] and ls.next() == "TK_else" do
        lex_opt(ls, "TK_newline")
        ls.step()
        if ls.token == "TK_if" then
            blocks[#blocks + 1] = parse_then(fn, ls, tests, line)
        else
            else_branch = parse_block(fn, ls, ls.line, "TK_else")
            break
        end
    end
    return ast.if_stmt(tests, blocks, else_branch, line)
end
local parse_do = function(fn, ls, line)
    ls.step()
    local body = parse_block(fn, ls, line, "TK_do")
    local lastline = ls.line
    return ast.do_stmt(body, line, lastline)
end
local parse_repeat = function(fn, ls, line)
    ls.step()
    scope.enter_block(fn, true)
    scope.enter_block(fn)
    local body, _, lastline = parse_opt_chunk(fn, ls, line, "TK_repeat")
    lex_match(ls, "TK_until", "TK_repeat", line)
    local cond = expr(fn, ls)
    scope.leave_block(fn)
    scope.leave_block(fn)
    return ast.repeat_stmt(cond, body, line, lastline)
end
local parse_break = function(fn, ls, line)
    ls.step()
    return ast.break_stmt(line)
end
local parse_label = function(fn, ls, line)
    ls.step()
    local name = lex_str(ls)
    lex_check(ls, "::")
    scope.dec_label(fn, name, line)
    return ast.label_stmt(name, line)
end
local parse_goto = function(fn, ls, line)
    local name = lex_str(ls)
    scope.dec_goto(name, line)
    return ast.goto_stmt(name, line)
end
local parse_stmt
parse_stmt = function(fn, ls)
    local line = ls.line
    local stmt
    if ls.token == "TK_if" then
        stmt = parse_if(fn, ls, line)
    elseif ls.token == "TK_for" then
        stmt = parse_for(fn, ls, line)
    elseif ls.token == "TK_while" then
        stmt = parse_while(fn, ls, line)
    elseif ls.token == "TK_do" then
        stmt = parse_do(fn, ls, line)
    elseif ls.token == "TK_repeat" then
        stmt = parse_repeat(fn, ls, line)
    elseif ls.token == "->" or ls.token == "~>" then
        err_syntax(ls, "lambda must either be assigned or invoked")
    elseif ls.token == "TK_name" and ls.value == "var" then
        ls.step()
        stmt = parse_var(fn, ls, line)
    elseif ls.token == "TK_local" then
        err_symbol(ls)
        ls.step()
        stmt = parse_var(fn, ls, line)
    elseif ls.token == "TK_return" then
        stmt = parse_return(fn, ls, line)
        return stmt, true
    elseif ls.token == "TK_break" then
        stmt = parse_break(fn, ls, line)
        return stmt, not LJ_52
    elseif ls.token == "::" then
        stmt = parse_label(fn, ls, line)
    elseif ls.token == "TK_goto" then
        if LJ_52 or ls.next() == "TK_name" then
            ls.step()
            stmt = parse_goto(fn, ls, line)
        end
    end
    if not stmt then
        stmt = parse_call_assign(fn, ls)
    end
    return stmt, false
end
local parse_chunk = function(fn, ls)
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
        stmt, islast = parse_stmt(fn, ls)
        body[#body + 1] = stmt
        skip_ends()
        if stmted == ls.line then
            if ls.token ~= "TK_eof" and ls.token ~= "TK_dedent" and ls.next() ~= "TK_eof" then
                err_instead(ls, 5, "only one statement allowed per line. %s expected", ls.astext("TK_newline"))
            end
        end
    end
    return body, firstline, ls.line
end
parse_opt_chunk = function(fn, ls, line, match_token)
    local body = {}
    if lex_indent(ls) then
        body = parse_chunk(fn, ls)
        if not lex_dedent(ls) then
            err_instead(ls, 10, "%s expected to end %s at line %d", ls.astext("TK_dedent"), ls.astext(match_token), line)
        end
    else
        if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
            body[1] = parse_stmt(fn, ls)
        end
        if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
            err_instead(ls, 10, "only one statement may stay near %s. %s expected", ls.astext(match_token), ls.astext("TK_newline"))
        elseif EndOfFunction[ls.token] then
            lex_opt(ls, ";")
        end
    end
    return body
end
parse_block = function(fn, ls, line, match)
    scope.enter_block(fn)
    local chunk = parse_opt_chunk(fn, ls, line, match)
    scope.leave_block(fn)
    return chunk
end
local parse_params = function(fn, ls)
    local args = {}
    if ls.token ~= "->" and ls.token ~= "~>" then
        repeat
            if ls.token == "TK_name" or not LJ_52 and ls.token == "TK_goto" then
                local name = lex_str(ls)
                name = declare_var(ls, name, nil)
                args[#args + 1] = ast.identifier(name)
            elseif ls.token == "..." then
                ls.step()
                fn.varargs = true
                args[#args + 1] = ast.expr_vararg()
                break
            else
                err_instead(ls, 10, "parameter expected for %s", ls.astext("->"))
            end
        until not lex_opt(ls, ",")
    end
    if ls.token == "->" then
        ls.step()
        return false, args
    elseif ls.token == "~>" then
        if fn.varargs then
            err_syntax(ls, "cannot curry variadic parameters with `~>`")
        end
        if #args < 2 then
            err_syntax(ls, "at least 2 parameters needed with `~>`")
        end
        ls.step()
        return true, args
    end
    err_expect(ls, "->")
end
parse_body = function(fn, ls, line)
    fn = scope.begin_func(fn)
    local curry, args = parse_params(fn, ls)
    local body = parse_opt_chunk(fn, ls, line, "->")
    fn = scope.end_func(fn)
    return curry, args, body, fn.varargs
end
local parse = function(ls)
    scope = scoping(function(em)
        err_warn(ls, em)
    end)
    local fn = scope.begin_func(nil)
    fn.varargs = true
    ls.step()
    lex_opt(ls, "TK_newline")
    local chunk, _, lastline = parse_chunk(fn, ls)
    fn = scope.end_func(fn)
    assert(fn == nil)
    if ls.token ~= "TK_eof" then
        err_warn(ls, "code should end. unexpected extra " .. ls.astext(ls.token))
    end
    return ast.chunk(chunk, ls.chunkname, 0, lastline)
end
return parse