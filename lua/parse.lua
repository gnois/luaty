--
-- Generated from parse.lt
--

local ast = require("lua.ast")
local ty = require("lua.type")
local operator = require("lua.operator")
local reserved = require("lua.reserved")
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
local type_tbl = function(scope, ls)
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
        local val = parse_type(scope, ls)
        local key
        if ls.token == ":" then
            ls.step()
            key = val
            val = parse_type(scope, ls)
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
local type_list = function(isparam, scope, ls)
    local list = {}
    if not (isparam and ls.token == "/" or ls.token == "]") then
        repeat
            if ls.token == "..." then
                ls.step()
                list[#list + 1] = parse_type(scope, ls, true)
                break
            else
                list[#list + 1] = parse_type(scope, ls)
            end
        until not lex_opt(ls, ",")
    end
    return list
end
local type_func = function(scope, ls)
    local line = ls.line
    ls.step()
    local params = type_list(true, scope, ls)
    local returns
    if ls.token == "/" then
        ls.step()
        returns = type_list(false, scope, ls)
    end
    lex_match(ls, "]", "[", line)
    return ty.func(params, returns)
end
local type_prefix = function(scope, ls)
    local typ
    if ls.token == "TK_name" then
        typ = ty.custom(ls.value)
        ls.step()
    elseif ls.token == "(" then
        local line = ls.line
        ls.step()
        typ = ty.bracket(parse_type(scope, ls))
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
type_basic = function(scope, ls)
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
                return type_func(scope, ls)
            end
            if ls.token == "{" then
                return type_tbl(scope, ls)
            end
            return type_prefix(scope, ls)
        end
    end
    ls.step()
    return typ
end
type_unary = function(scope, ls)
    local tk = ls.token
    if tk == "!" then
        ls.step()
        local t = type_binary(scope, ls, operator.unary_priority)
        return ty["not"](t)
    else
        return type_basic(scope, ls)
    end
end
type_binary = function(scope, ls, limit)
    local l = type_unary(scope, ls)
    local op = ls.token
    while operator.is_typeop(op) and operator.left_priority(op) > limit do
        ls.step()
        local r, nextop = type_binary(scope, ls, operator.right_priority(op))
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
parse_type = function(scope, ls, varargs)
    local typ = type_binary(scope, ls, 0)
    if typ and varargs then
        return ty.varargs(typ)
    end
    return typ
end
local expr_primary, expr, expr_unop, expr_binop, expr_simple, expr_list, expr_table
local parse_body, parse_args, parse_block, parse_opt_chunk
local declare_var = function(scope, ls, name, vtype)
    if name == "@" then
        name = "self"
    end
    scope.new_var(name, vtype, ls.line)
    return name
end
local var_name = function(scope, ls)
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
local expr_bracket = function(scope, ls)
    ls.step()
    local v = expr(scope, ls)
    lex_check(ls, "]")
    return v
end
expr_table = function(scope, ls)
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
            key = expr_bracket(scope, ls)
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
        local val = expr(scope, ls)
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
local expr_function = function(scope, ls)
    local line = ls.line
    if ls.token == "\\" then
        ls.step()
    end
    local curry, params, body, varargs = parse_body(scope, ls, line)
    local lambda = ast.expr_function(params, body, varargs)
    if curry then
        if scope.declared("curry") == 0 then
            err_warn(ls, "require('lib.curry') is needed to use `~>`")
        end
        local cargs = {ast.literal(#params), lambda}
        return ast.expr_function_call(ast.identifier("curry"), cargs, line)
    end
    return lambda
end
expr_simple = function(scope, ls)
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
        if not scope.is_varargs() then
            err_syntax(ls, "cannot use `...` in a function without variable arguments")
        end
        e = ast.expr_vararg()
    elseif tk == "{" then
        return expr_table(scope, ls)
    elseif tk == "\\" or tk == "->" or tk == "~>" then
        return expr_function(scope, ls)
    else
        return expr_primary(scope, ls)
    end
    ls.step()
    return e
end
expr_list = function(scope, ls, nmax)
    local exps = {}
    exps[1] = expr(scope, ls)
    while ls.token == "," do
        ls.step()
        exps[#exps + 1] = expr(scope, ls)
    end
    local n = #exps
    if nmax and n > nmax then
        err_warn(ls, "assigning " .. n .. " values to " .. nmax .. " variable(s)")
    end
    return exps
end
expr_unop = function(scope, ls)
    local tk = ls.token
    if tk == "TK_not" or tk == "-" or tk == "#" then
        local line = ls.line
        ls.step()
        local v = expr_binop(scope, ls, operator.unary_priority)
        return ast.expr_unop(ls.tostr(tk), v, line)
    else
        return expr_simple(scope, ls)
    end
end
expr_binop = function(scope, ls, limit)
    local v = expr_unop(scope, ls)
    local op = ls.tostr(ls.token)
    while operator.is_binop(op) and operator.left_priority(op) > limit do
        local line = ls.line
        ls.step()
        local v2, nextop = expr_binop(scope, ls, operator.right_priority(op))
        v = ast.expr_binop(op, v, v2, line)
        op = nextop
    end
    return v, op
end
expr = function(scope, ls)
    return expr_binop(scope, ls, 0)
end
expr_primary = function(scope, ls)
    local v, vk
    if ls.token == "(" then
        local line = ls.line
        ls.step()
        vk, v = Kind.Expr, ast.expr_brackets(expr(scope, ls))
        lex_match(ls, ")", "(", line)
    else
        v, vk = var_name(scope, ls)
    end
    local val, key
    while true do
        local line = ls.line
        if ls.token == "." then
            vk, v, val, key = Kind.Field, expr_field(ls, v)
        elseif ls.token == "[" then
            key = expr_bracket(scope, ls)
            val = v
            vk, v = Kind.Index, ast.expr_index(val, key)
        elseif ls.token == "(" then
            local args, self1 = parse_args(scope, ls)
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
local parse_return = function(scope, ls, line)
    ls.step()
    ast.has_return = true
    local exps
    if EndOfChunk[ls.token] or NewLine[ls.token] or EndOfFunction[ls.token] then
        exps = {}
    else
        exps = expr_list(scope, ls)
    end
    return ast.return_stmt(exps, line)
end
local parse_for_num = function(scope, ls, varname, line)
    lex_check(ls, "=")
    local init = expr(scope, ls)
    lex_check(ls, ",")
    local last = expr(scope, ls)
    local step
    if lex_opt(ls, ",") then
        step = expr(scope, ls)
    else
        step = ast.literal(1)
    end
    scope.enter_block()
    local name = declare_var(scope, ls, varname, nil)
    local v = ast.identifier(name)
    local body = parse_block(scope, ls, line, "TK_for")
    scope.leave_block()
    return ast.for_stmt(v, init, last, step, body, line, ls.line)
end
local parse_for_iter = function(scope, ls, indexname)
    scope.enter_block("ForIter")
    local name = declare_var(scope, ls, indexname, nil)
    local vars = {ast.identifier(name)}
    while lex_opt(ls, ",") do
        name = lex_str(ls)
        name = declare_var(scope, ls, name, nil)
        vars[#vars + 1] = ast.identifier(name)
    end
    lex_check(ls, "TK_in")
    local line = ls.line
    local exps = expr_list(scope, ls)
    local body = parse_block(scope, ls, line, "TK_for")
    scope.leave_block()
    return ast.for_iter_stmt(vars, exps, body, line, ls.line)
end
local parse_for = function(scope, ls, line)
    ls.step()
    scope.enter_block("ForNum")
    local varname = lex_str(ls)
    local stmt
    if ls.token == "=" then
        stmt = parse_for_num(scope, ls, varname, line)
    elseif ls.token == "," or ls.token == "TK_in" then
        stmt = parse_for_iter(scope, ls, varname)
    else
        err_instead(ls, 10, "%s expected", "`=` or `in`")
    end
    scope.leave_block()
    return stmt
end
parse_args = function(scope, ls)
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
            args[#args + 1] = expr(scope, ls)
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
parse_assignment = function(scope, ls, vlist, v, vk)
    local line = ls.line
    if vk ~= Kind.Var and vk ~= Kind.Field and vk ~= Kind.Index then
        err_symbol(ls)
    end
    vlist[#vlist + 1] = v
    if lex_opt(ls, ",") then
        local n_var, n_vk = expr_primary(scope, ls)
        return parse_assignment(scope, ls, vlist, n_var, n_vk)
    else
        lex_check(ls, "=")
        local exps = expr_list(scope, ls, #vlist)
        return ast.assignment_expr(vlist, exps, line)
    end
end
local parse_call_assign = function(scope, ls)
    local v, vk = expr_primary(scope, ls)
    if vk == Kind.Call then
        return ast.new_statement_expr(v, ls.line)
    else
        local vlist = {}
        return parse_assignment(scope, ls, vlist, v, vk)
    end
end
local parse_var = function(scope, ls)
    local line = ls.line
    local lhs = {}
    repeat
        local name = lex_str(ls)
        local typ = parse_type(scope, ls)
        name = declare_var(scope, ls, name, nil)
        lhs[#lhs + 1] = ast.identifier(name)
    until not lex_opt(ls, ",")
    local rhs
    if lex_opt(ls, "=") then
        rhs = expr_list(scope, ls, #lhs)
    else
        rhs = {}
    end
    return ast.local_decl(lhs, rhs, line)
end
local parse_while = function(scope, ls, line)
    ls.step()
    local cond = expr(scope, ls)
    scope.enter_block("While")
    local body = parse_block(scope, ls, line, "TK_while")
    scope.leave_block()
    local lastline = ls.line
    return ast.while_stmt(cond, body, line, lastline)
end
local parse_then = function(scope, ls, tests, line)
    ls.step()
    tests[#tests + 1] = expr(scope, ls)
    if ls.token == "TK_then" then
        err_warn(ls, "`then` is not needed")
        ls.step()
    end
    return parse_block(scope, ls, line, "TK_if")
end
local parse_if = function(scope, ls, line)
    local tests, blocks = {}, {}
    blocks[#blocks + 1] = parse_then(scope, ls, tests, line)
    local else_branch
    while ls.token == "TK_else" or NewLine[ls.token] and ls.next() == "TK_else" do
        lex_opt(ls, "TK_newline")
        ls.step()
        if ls.token == "TK_if" then
            blocks[#blocks + 1] = parse_then(scope, ls, tests, line)
        else
            else_branch = parse_block(scope, ls, ls.line, "TK_else")
            break
        end
    end
    return ast.if_stmt(tests, blocks, else_branch, line)
end
local parse_do = function(scope, ls, line)
    ls.step()
    local body = parse_block(scope, ls, line, "TK_do")
    local lastline = ls.line
    return ast.do_stmt(body, line, lastline)
end
local parse_repeat = function(scope, ls, line)
    ls.step()
    scope.enter_block("Repeat")
    scope.enter_block()
    local body, _, lastline = parse_opt_chunk(scope, ls, line, "TK_repeat")
    lex_match(ls, "TK_until", "TK_repeat", line)
    local cond = expr(scope, ls)
    scope.leave_block()
    scope.leave_block()
    return ast.repeat_stmt(cond, body, line, lastline)
end
local parse_break = function(scope, ls, line)
    ls.step()
    scope.new_break()
    return ast.break_stmt(line)
end
local parse_label = function(scope, ls, line)
    ls.step()
    local name = lex_str(ls)
    lex_check(ls, "::")
    scope.new_label(name, line)
    return ast.label_stmt(name, line)
end
local parse_goto = function(scope, ls, line)
    local name = lex_str(ls)
    scope.new_goto(name, line)
    return ast.goto_stmt(name, line)
end
local parse_stmt
parse_stmt = function(scope, ls)
    local line = ls.line
    local stmt
    if ls.token == "TK_if" then
        stmt = parse_if(scope, ls, line)
    elseif ls.token == "TK_for" then
        stmt = parse_for(scope, ls, line)
    elseif ls.token == "TK_while" then
        stmt = parse_while(scope, ls, line)
    elseif ls.token == "TK_do" then
        stmt = parse_do(scope, ls, line)
    elseif ls.token == "TK_repeat" then
        stmt = parse_repeat(scope, ls, line)
    elseif ls.token == "->" or ls.token == "~>" then
        err_syntax(ls, "lambda must either be assigned or invoked")
    elseif ls.token == "TK_name" and ls.value == "var" then
        ls.step()
        stmt = parse_var(scope, ls, line)
    elseif ls.token == "TK_local" then
        err_symbol(ls)
        ls.step()
        stmt = parse_var(scope, ls, line)
    elseif ls.token == "TK_return" then
        stmt = parse_return(scope, ls, line)
        return stmt, true
    elseif ls.token == "TK_break" then
        stmt = parse_break(scope, ls, line)
        return stmt, not LJ_52
    elseif ls.token == "::" then
        stmt = parse_label(scope, ls, line)
    elseif ls.token == "TK_goto" then
        if LJ_52 or ls.next() == "TK_name" then
            ls.step()
            stmt = parse_goto(scope, ls, line)
        end
    end
    if not stmt then
        stmt = parse_call_assign(scope, ls)
    end
    return stmt, false
end
local parse_chunk = function(scope, ls)
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
        stmt, islast = parse_stmt(scope, ls)
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
parse_opt_chunk = function(scope, ls, line, match_token)
    local body = {}
    if lex_indent(ls) then
        body = parse_chunk(scope, ls)
        if not lex_dedent(ls) then
            err_instead(ls, 10, "%s expected to end %s at line %d", ls.astext("TK_dedent"), ls.astext(match_token), line)
        end
    else
        if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
            body[1] = parse_stmt(scope, ls)
        end
        if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
            err_instead(ls, 10, "statement should end near %s. %s expected", ls.astext(match_token), ls.astext("TK_newline"))
        elseif EndOfFunction[ls.token] then
            lex_opt(ls, ";")
        end
    end
    return body
end
parse_block = function(scope, ls, line, match)
    scope.enter_block()
    local chunk = parse_opt_chunk(scope, ls, line, match)
    scope.leave_block()
    return chunk
end
local parse_params = function(scope, ls)
    local params = {}
    local rettyp = {}
    if ls.token ~= "->" and ls.token ~= "~>" then
        repeat
            if ls.token == "TK_name" or not LJ_52 and ls.token == "TK_goto" then
                local name = lex_str(ls)
                local typ = parse_type(scope, ls)
                name = declare_var(scope, ls, name, nil)
                params[#params + 1] = ast.identifier(name)
            elseif ls.token == "..." then
                ls.step()
                local typ = parse_type(scope, ls, true)
                scope.varargs()
                params[#params + 1] = ast.expr_vararg()
                if ls.next() ~= "/" then
                    break
                end
            elseif ls.token == "/" then
                ls.step()
                repeat
                    rettyp[#rettyp + 1] = parse_type(scope, ls)
                until not lex_opt(ls, ",")
                break
            else
                err_instead(ls, 10, "parameter expected for %s", ls.astext("->"))
            end
        until not lex_opt(ls, ",") and ls.token ~= "/"
    end
    if ls.token == "->" then
        ls.step()
        return false, params
    elseif ls.token == "~>" then
        if scope.is_varargs() then
            err_syntax(ls, "cannot curry variadic parameters with `~>`")
        end
        if #params < 2 then
            err_syntax(ls, "at least 2 parameters needed with `~>`")
        end
        ls.step()
        return true, params
    end
    err_expect(ls, "->")
end
parse_body = function(scope, ls, line)
    scope.begin_func()
    local curry, params = parse_params(scope, ls)
    local body = parse_opt_chunk(scope, ls, line, "->")
    scope.end_func()
    return curry, params, body, scope.is_varargs()
end
local parse = function(scope, ls)
    scope.begin_func()
    scope.varargs()
    ls.step()
    lex_opt(ls, "TK_newline")
    local chunk, _, lastline = parse_chunk(scope, ls)
    scope.end_func()
    if ls.token ~= "TK_eof" then
        err_warn(ls, "code should end. unexpected extra " .. ls.astext(ls.token))
    end
    return ast.chunk(chunk, ls.chunkname, 0, lastline)
end
return parse