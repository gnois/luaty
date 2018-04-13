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
return function(ls, warn)
    local stmted
    local parse_error = function(severe, em, ...)
        local loc = ls.loc()
        warn(loc.line, loc.col, severe, string.format(em, ...))
    end
    local err_warn = function(em)
        parse_error(2, "%s", em)
    end
    local err_syntax = function(em)
        parse_error(10, "%s", em)
    end
    local ls_value = function()
        if ls.value then
            return "'" .. ls.value .. "'"
        end
    end
    local err_instead = function(severe, em, ...)
        local msg = string.format(em, ...)
        parse_error(severe, "%s instead of %s", msg, ls_value() or ls.astext(ls.token))
    end
    local err_expect = function(token)
        err_instead(10, "%s expected", ls.astext(token))
    end
    local err_symbol = function()
        local sym = ls.tostr(ls.token)
        local replace = {["end"] = "<dedent>", ["local"] = "`var`", ["function"] = "\\...->", ["elseif"] = "`else if`", ["repeat"] = "`do`"}
        local rep = replace[sym]
        if rep then
            parse_error(7, "use %s instead of '%s'", rep, sym)
        else
            parse_error(10, "unexpected %s", ls_value() or ls.astext(ls.token))
        end
    end
    local is_keyword = function()
        local str = ls.tostr(ls.token)
        if Keyword[str] then
            return str
        end
    end
    local lex_opt = function(tok)
        if ls.token == tok then
            ls.step()
            return true
        end
        return false
    end
    local lex_check = function(tok)
        if ls.token ~= tok then
            err_expect(tok)
        end
        ls.step()
    end
    local lex_match = function(what, who, line)
        if not lex_opt(what) then
            if line == ls.line then
                err_expect(what)
            else
                err_instead(10, "%s expected to match %s at line %d", ls.astext(what), ls.astext(who), line)
            end
            return false
        end
        return true
    end
    local lex_str = function()
        local loc = ls.loc()
        local s
        if ls.token ~= "TK_name" and (LJ_52 or ls.token ~= "TK_goto") then
            err_expect("TK_name")
            s = ls.tostr(ls.token)
        else
            s = ls.value
        end
        ls.step()
        return s, loc
    end
    local lex_indent = function()
        if NewLine[ls.token] and ls.next() == "TK_indent" then
            lex_opt("TK_newline")
            ls.step()
            return true
        end
        return false
    end
    local lex_dedent = function()
        if ls.token == "TK_dedent" or NewLine[ls.token] and ls.next() == "TK_dedent" then
            lex_opt("TK_newline")
            ls.step()
            return true
        end
        return false
    end
    local lex_opt_dent = function(dented)
        if not dented then
            dented = lex_indent()
        else
            dented = not lex_dedent()
        end
        lex_opt("TK_newline")
        return dented
    end
    local parse_type, type_unary, type_binary, type_basic
    local type_tbl = function()
        local line = ls.line
        ls.step()
        local kvs = {}
        local dented = false
        while ls.token ~= "}" do
            dented = lex_opt_dent(dented)
            if not dented and ls.token == "TK_dedent" then
                err_symbol()
                ls.step()
            end
            if ls.token == "}" then
                break
            end
            local val = parse_type()
            local key
            if ls.token == ":" then
                ls.step()
                key = val
                val = parse_type()
            end
            if key then
                for i = 1, #kvs do
                    local arr = kvs[i]
                    if ast.same(arr[2], key) then
                        parse_error(10, "similar key type at position %i and %i in table type annotation", i, (#kvs + 1))
                    end
                end
            else
                if not val then
                    err_instead(10, "type expected in table type annotation")
                else
                    for i = 1, #kvs do
                        local arr = kvs[i]
                        if not arr[2] and ast.same(arr[1], val) then
                            parse_error(10, "similar value type at position %i and %i in table type annotation", i, (#kvs + 1))
                        end
                    end
                end
            end
            kvs[#kvs + 1] = {val, key}
            dented = lex_opt_dent(dented)
            if not lex_opt(",") then
                break
            end
        end
        if dented and not lex_dedent() then
            err_instead(10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
        end
        lex_match("}", "{", line)
        return ty.tbl(kvs)
    end
    local type_list = function(isparam)
        local list = {}
        if not (isparam and ls.token == "/" or ls.token == "]") then
            repeat
                if ls.token == "..." then
                    ls.step()
                    list[#list + 1] = parse_type(true)
                    break
                else
                    list[#list + 1] = parse_type()
                end
            until not lex_opt(",")
        end
        return list
    end
    local type_func = function()
        local line = ls.line
        ls.step()
        local params = type_list(true)
        local returns
        if ls.token == "/" then
            ls.step()
            returns = type_list(false)
        end
        lex_match("]", "[", line)
        return ty.func(params, returns)
    end
    local type_prefix = function()
        local typ
        if ls.token == "TK_name" then
            typ = ty.custom(ls.value)
            ls.step()
        elseif ls.token == "(" then
            local line = ls.line
            ls.step()
            typ = ty.bracket(parse_type())
            lex_match(")", "(", line)
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
    type_basic = function()
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
                    return type_func()
                end
                if ls.token == "{" then
                    return type_tbl()
                end
                return type_prefix()
            end
        end
        ls.step()
        return typ
    end
    type_unary = function()
        local tk = ls.token
        if tk == "!" then
            ls.step()
            local t = type_binary(operator.unary_priority)
            return ty["not"](t)
        else
            return type_basic()
        end
    end
    type_binary = function(limit)
        local l = type_unary()
        local op = ls.token
        while operator.is_typeop(op) and operator.left_priority(op) > limit do
            ls.step()
            local r, nextop = type_binary(operator.right_priority(op))
            if op == "?" then
                l = ty["or"](l, ty["nil"]())
            elseif op == "|" then
                l = ty["or"](l, r)
            elseif op == "&" then
                l = ty["and"](l, r)
            else
                parse_error(10, "unexpected %s", ls_value() or ls.astext(ls.token))
                break
            end
            op = nextop
        end
        return l, op
    end
    parse_type = function(varargs)
        local typ = type_binary(0)
        if typ and varargs then
            return ty.varargs(typ)
        end
        return typ
    end
    local expr_primary, expr, expr_unop, expr_binop, expr_simple, expr_list, expr_table
    local parse_body, parse_args, parse_block
    local expr_bracket = function()
        ls.step()
        local v = expr()
        lex_check("]")
        return v
    end
    expr_table = function(loc)
        local kvs = {}
        local dented = false
        lex_check("{")
        while ls.token ~= "}" do
            dented = lex_opt_dent(dented)
            if not dented and ls.token == "TK_dedent" then
                err_symbol()
                ls.step()
            end
            if ls.token == "}" then
                break
            end
            local key
            if ls.token == "[" then
                key = expr_bracket()
                lex_check("=")
            elseif ls.next() == "=" then
                if ls.token == "TK_name" then
                    local name, at = lex_str()
                    key = Expr.string(name, false, at)
                elseif ls.token == "TK_string" then
                    key = Expr.string(ls.value, false, ls)
                    ls.step()
                else
                    local name = is_keyword()
                    if name then
                        key = Expr.string(name, false, ls)
                    else
                        err_syntax("invalid table key " .. ls_value() or ls.astext(ls.token))
                    end
                    ls.step()
                end
                lex_check("=")
            end
            local val = expr()
            if key then
                for i = 1, #kvs do
                    local arr = kvs[i]
                    if ast.same(arr[2], key) then
                        err_warn("duplicate key at position " .. i .. " and " .. #kvs + 1 .. " in table")
                    end
                end
            end
            kvs[#kvs + 1] = {val, key}
            dented = lex_opt_dent(dented)
            if ls.token == ";" then
                err_instead(3, "use `,`")
            end
            if not lex_opt(",") and not lex_opt(";") then
                break
            end
        end
        if dented and not lex_dedent() then
            err_instead(10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), loc.line)
        end
        lex_match("}", "{", loc.line)
        return Expr.table(kvs, loc)
    end
    local expr_function = function(loc)
        if ls.token == "\\" then
            ls.step()
        end
        local curry, params, body, varargs = parse_body(loc.line)
        local lambda = Expr["function"](params, body, varargs, loc)
        if curry then
            local cargs = {Expr.number(#params, loc), lambda}
            return Expr.call(Expr.id("curry", loc), cargs, loc)
        end
        return lambda
    end
    expr_simple = function()
        local tk, val = ls.token, ls.value
        local loc = ls.loc()
        local e
        if tk == "TK_number" then
            e = Expr.number(val, loc)
        elseif tk == "TK_string" then
            e = Expr.string(val, false, loc)
        elseif tk == "TK_longstring" then
            e = Expr.string(val, true, loc)
        elseif tk == "TK_nil" then
            e = Expr.null(loc)
        elseif tk == "TK_true" then
            e = Expr.bool(true, loc)
        elseif tk == "TK_false" then
            e = Expr.bool(false, loc)
        elseif tk == "..." then
            e = Expr.vararg(loc)
        elseif tk == "{" then
            return expr_table(loc)
        elseif tk == "\\" or tk == "->" or tk == "~>" then
            return expr_function(loc)
        else
            return expr_primary()
        end
        ls.step()
        return e
    end
    expr_list = function(nmax)
        local exps = {}
        exps[1] = expr()
        while ls.token == "," do
            ls.step()
            exps[#exps + 1] = expr()
        end
        local n = #exps
        if nmax and n > nmax then
            err_warn("assigning " .. n .. " values to " .. nmax .. " variable(s)")
        end
        return exps
    end
    expr_unop = function()
        local tk = ls.token
        if tk == "TK_not" or tk == "-" or tk == "#" then
            ls.step()
            local v = expr_binop(operator.unary_priority)
            return Expr.unary(ls.tostr(tk), v, ls)
        else
            return expr_simple()
        end
    end
    expr_binop = function(limit)
        local v = expr_unop()
        local op = ls.tostr(ls.token)
        while operator.is_binop(op) and operator.left_priority(op) > limit do
            ls.step()
            local v2, nextop = expr_binop(operator.right_priority(op))
            v = Expr.binary(op, v, v2, ls)
            op = nextop
        end
        return v, op
    end
    expr = function()
        return expr_binop(0)
    end
    expr_primary = function()
        local v, vk
        if ls.token == "(" then
            local line = ls.line
            ls.step()
            vk, v = Kind.Expr, ast.bracket(expr())
            lex_match(")", "(", line)
        else
            v, vk = Expr.id(lex_str()), Kind.Var
        end
        local key
        while true do
            local at = ls.loc()
            if ls.token == "." then
                ls.step()
                local kw = is_keyword()
                if kw then
                    key = Expr.string(kw, false, ls)
                    vk, v = Kind.Index, Expr.index(v, key, at)
                    ls.step()
                else
                    key = lex_str()
                    vk, v = Kind.Property, Expr.property(v, key, at)
                end
            elseif ls.token == "[" then
                key = expr_bracket()
                vk, v = Kind.Index, Expr.index(v, key, at)
            elseif ls.token == "(" then
                local args = parse_args()
                vk, v = Kind.Call, Expr.call(v, args, at)
            else
                break
            end
        end
        return v, vk
    end
    local parse_return = function(loc)
        ls.step()
        local exps
        if EndOfChunk[ls.token] or NewLine[ls.token] or EndOfFunction[ls.token] then
            exps = {}
        else
            exps = expr_list()
        end
        return Stmt["return"](exps, loc)
    end
    local parse_for_num = function(idxname, idxloc, loc)
        local var = Expr.id(idxname, idxloc)
        lex_check("=")
        local first = expr()
        lex_check(",")
        local last = expr()
        local step
        if lex_opt(",") then
            step = expr()
        end
        local body = parse_block(loc.line, "TK_for")
        return Stmt.fornum(var, first, last, step, body, loc)
    end
    local parse_for_in = function(idxname, idxloc, loc)
        local vars = {Expr.id(idxname, idxloc)}
        while lex_opt(",") do
            vars[#vars + 1] = Expr.id(lex_str())
        end
        lex_check("TK_in")
        local exps = expr_list()
        local body = parse_block(loc.line, "TK_for")
        return Stmt.forin(vars, exps, body, loc)
    end
    local parse_for = function(loc)
        ls.step()
        local idxname, idxloc = lex_str()
        local stmt
        if ls.token == "=" then
            stmt = parse_for_num(idxname, idxloc, loc)
        elseif ls.token == "," or ls.token == "TK_in" then
            stmt = parse_for_in(idxname, idxloc, loc)
        else
            err_instead(10, "`=` or `in` expected")
        end
        return stmt
    end
    parse_args = function()
        local line = ls.line
        lex_check("(")
        if not LJ_52 and line ~= ls.prevline then
            err_warn("ambiguous syntax (function call x new statement)")
        end
        local dented = false
        local args = {}
        while ls.token ~= ")" do
            dented = lex_opt_dent(dented)
            if not dented and ls.token == "TK_dedent" then
                err_symbol()
                ls.step()
            end
            if ls.token == ")" then
                break
            end
            args[#args + 1] = expr()
            dented = lex_opt_dent(dented)
            if not lex_opt(",") then
                break
            end
        end
        if dented and not lex_dedent() then
            err_instead(10, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
        end
        lex_match(")", "(", line)
        return args
    end
    local parse_assignment
    parse_assignment = function(lhs, v, vk)
        local loc = ls.loc()
        if vk ~= Kind.Var and vk ~= Kind.Property and vk ~= Kind.Index then
            err_symbol()
        end
        lhs[#lhs + 1] = v
        if lex_opt(",") then
            local n_var, n_vk = expr_primary()
            return parse_assignment(lhs, n_var, n_vk)
        else
            lex_check("=")
            local exps = expr_list(#lhs)
            return Stmt.assign(lhs, exps, loc)
        end
    end
    local parse_call_assign = function(loc)
        local v, vk = expr_primary()
        if vk == Kind.Call then
            return Stmt.expression(v, loc)
        else
            local lhs = {}
            return parse_assignment(lhs, v, vk)
        end
    end
    local parse_var = function(loc)
        local names, locs = {}, {}
        repeat
            local name, at = lex_str()
            local typ = parse_type()
            names[#names + 1] = name
            locs[#locs + 1] = at
        until not lex_opt(",")
        local rhs = {}
        if lex_opt("=") then
            rhs = expr_list(#names)
        end
        local lhs = {}
        for i, name in ipairs(names) do
            lhs[i] = Expr.id(name, locs[i])
        end
        return Stmt["local"](lhs, rhs, loc)
    end
    local parse_while = function(loc)
        ls.step()
        local cond = expr()
        local body = parse_block(loc.line, "TK_while")
        return Stmt["while"](cond, body, loc)
    end
    local parse_then = function(tests, line)
        ls.step()
        tests[#tests + 1] = expr()
        if ls.token == "TK_then" then
            err_warn("`then` is not needed")
            ls.step()
        end
        return parse_block(line, "TK_if")
    end
    local parse_if = function(loc)
        local tests, blocks = {}, {}
        blocks[#blocks + 1] = parse_then(tests, ls.line)
        local else_branch
        while ls.token == "TK_else" or NewLine[ls.token] and ls.next() == "TK_else" do
            lex_opt("TK_newline")
            ls.step()
            if ls.token == "TK_if" then
                blocks[#blocks + 1] = parse_then(tests, ls.line)
            else
                else_branch = parse_block(ls.line, "TK_else")
                break
            end
        end
        return Stmt["if"](tests, blocks, else_branch, loc)
    end
    local parse_do = function(loc)
        ls.step()
        local body = parse_block(loc.line, "TK_do")
        if lex_opt("TK_until") then
            local cond = expr()
            return Stmt["repeat"](cond, body, loc)
        end
        return Stmt["do"](body, loc)
    end
    local parse_break = function(loc)
        ls.step()
        return Stmt["break"](loc)
    end
    local parse_label = function(loc)
        ls.step()
        local name = lex_str()
        lex_check("::")
        return Stmt.label(name, loc)
    end
    local parse_goto = function(loc)
        local name = lex_str()
        return Stmt["goto"](name, loc)
    end
    local parse_stmt
    parse_stmt = function()
        local loc = ls.loc()
        local stmt
        if ls.token == "TK_if" then
            stmt = parse_if(loc)
        elseif ls.token == "TK_for" then
            stmt = parse_for(loc)
        elseif ls.token == "TK_while" then
            stmt = parse_while(loc)
        elseif ls.token == "TK_do" then
            stmt = parse_do(loc)
        elseif ls.token == "TK_repeat" then
            err_symbol()
            stmt = parse_do(loc)
        elseif ls.token == "\\" or ls.token == "->" or ls.token == "~>" then
            err_syntax("lambda must either be assigned or immediately invoked")
            stmt = expr_function(loc)
        elseif ls.token == "TK_name" and ls.value == "var" then
            ls.step()
            stmt = parse_var(loc)
        elseif ls.token == "TK_local" then
            err_symbol()
            ls.step()
            stmt = parse_var(loc)
        elseif ls.token == "TK_return" then
            stmt = parse_return(loc)
            return stmt, true
        elseif ls.token == "TK_break" then
            stmt = parse_break(loc)
            return stmt, not LJ_52
        elseif ls.token == "::" then
            stmt = parse_label(loc)
        elseif ls.token == "TK_goto" then
            if LJ_52 or ls.next() == "TK_name" then
                ls.step()
                stmt = parse_goto(loc)
            end
        end
        if not stmt then
            stmt = parse_call_assign(loc)
        end
        return stmt, false
    end
    local parse_stmts = function()
        local skip_ends = function()
            while ls.token == ";" or ls.token == "TK_end" do
                err_symbol()
                ls.step()
            end
            lex_opt("TK_newline")
        end
        local stmt, islast = nil, false
        local body = {}
        while not islast and not EndOfChunk[ls.token] do
            stmted = ls.line
            skip_ends()
            stmt, islast = parse_stmt()
            body[#body + 1] = stmt
            skip_ends()
            if stmted == ls.line then
                if ls.token ~= "TK_eof" and ls.token ~= "TK_dedent" and ls.next() ~= "TK_eof" then
                    err_instead(5, "statement should end. %s expected", ls.astext("TK_newline"))
                end
            end
        end
        return body
    end
    parse_block = function(line, match_token)
        local body
        if lex_indent() then
            body = parse_stmts()
            if not lex_dedent() then
                err_instead(10, "%s expected to end %s at line %d", ls.astext("TK_dedent"), ls.astext(match_token), line)
            end
        else
            if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
                body = {(parse_stmt())}
            end
            if not EndOfChunk[ls.token] and not NewLine[ls.token] and not EndOfFunction[ls.token] then
                err_instead(10, "statement should end near %s. %s expected", ls.astext(match_token), ls.astext("TK_newline"))
            elseif EndOfFunction[ls.token] then
                lex_opt(";")
            end
        end
        return body or {}
    end
    local parse_params = function()
        local params = {}
        local rettyp = {}
        local varargs = false
        if ls.token ~= "->" and ls.token ~= "~>" then
            repeat
                if ls.token == "TK_name" or not LJ_52 and ls.token == "TK_goto" then
                    local name, at = lex_str()
                    local typ = parse_type()
                    params[#params + 1] = Expr.id(name, at)
                elseif ls.token == "..." then
                    ls.step()
                    varargs = true
                    local typ = parse_type(true)
                    params[#params + 1] = Expr.vararg(ls)
                    if ls.next() ~= "/" then
                        break
                    end
                elseif ls.token == "/" then
                    ls.step()
                    repeat
                        rettyp[#rettyp + 1] = parse_type()
                    until not lex_opt(",")
                    break
                else
                    err_instead(10, "parameter expected for `->`")
                end
            until not lex_opt(",") and ls.token ~= "/"
        end
        if ls.token == "->" then
            ls.step()
            return false, params, varargs
        elseif ls.token == "~>" then
            ls.step()
            if varargs then
                err_syntax("cannot curry variadic parameters with `~>`")
            end
            if #params < 2 then
                err_syntax("at least 2 parameters needed with `~>`")
            end
            return true, params, varargs
        end
        err_expect("->")
    end
    parse_body = function(line)
        local curry, params, varargs = parse_params()
        local body = parse_block(line, "->")
        return curry, params, body, varargs
    end
    ls.step()
    lex_opt("TK_newline")
    local chunk = parse_stmts()
    if ls.token ~= "TK_eof" then
        err_warn("code should end. unexpected extra " .. ls.astext(ls.token))
    end
    return chunk
end