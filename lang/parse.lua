local operator = require("lang.operator")

local LJ_52 = false

local IsLastStatement = { TK_return = true, TK_break  = true }
local EndOfBlock = { TK_dedent = true, TK_else = true, TK_until = true, TK_eof = true }
local EmptyFunction = { TK_newline = true, [','] = true, ['}'] = true, [')'] = true }
-- indentation stack within a multi line expr/stmt
local indent

local function err_syntax(ls, em)
    --ls:error(ls.token, em)
    local msg = string.format("%s:%d   %s", ls.chunkname, ls.linenumber, em)
    error("LT-ERROR" .. msg, 0)
end

local function err_token(ls, token)
    ls:error(ls.token, "'%s' expected", ls.token2str(token))
end

local function err_symbol(ls)
    local sym = ls.tokenval or ls.token2str(ls.token)
    local replace = {['end'] = "<dedent>", ['local'] = "'var'", ['function'] = "\\...->", ['elseif'] = "'else if'", ['repeat'] = "'do'"}
    local rep = replace[sym]
    local msg
    if rep then
        msg = string.format("use %s instead of '%s'", rep, sym)
    else
        msg = string.format("unexpected %s", sym)
    end
    err_syntax(ls, msg)
end

local function lex_opt(ls, tok)
    if ls.token == tok then
        ls:next()
        return true
    end
    return false
end

-- return true only if a real indent is eaten
local function lex_indent(ls, eat_nl)
    if ls.token == 'TK_newline' then
        if ls:lookahead() == 'TK_indent' then
            ls:next()  -- eat the newline
            ls:next()
            indent = indent + 1
            return true
        else
            if eat_nl then
                ls:next()
            end
        end
    end
    return false
end

-- return true only if a real dedent is eaten
local function lex_dedent(ls, eat_nl)
    if indent > 0 then
        if ls.token == 'TK_newline' then
            if ls:lookahead() == 'TK_dedent' then
                ls:next()  -- eat the newline
                ls:next()
                indent = indent - 1
                return true
            else
                if eat_nl then
                    ls:next()  -- eat the newline
                end
            end
        elseif ls.token == 'TK_dedent' then
            ls:next()
            indent = indent - 1
            return true
        end
    end
    return false
end

local function lex_check(ls, tok)
    if ls.token ~= tok then err_token(ls, tok) end
    ls:next()
end

local function lex_match(ls, what, who, line)
    if not lex_opt(ls, what) then
        if line == ls.linenumber then
            err_token(ls, what)
        else
            local token2str = ls.token2str
            ls:error(ls.token, "'%s' expected to match '%s' at line %d", token2str(what), token2str(who), line)
        end
    end
end

local function in_scope(ast, ls, var)
    if var.name then
        local scope = ast.current
        while not scope.vars[var.name] do
            scope = scope.parent
            if not scope then
                return false
            end
        end
        return true
    end
    return false
end

local function shadow_check(ast, ls, vars)
    local n = #vars
    for i = 1, n do
        local v = vars[i]
        for j = i+1, n do
            if vars[j] == v then
                err_syntax(ls, "duplicate `var " .. v .. "`")
            end
        end

        local scope = ast.current
        repeat
            if scope.vars[v] then
                err_syntax(ls, "shadowing previous `var " .. v .. "`")
            end
            scope = scope.parent
        until not scope
    end
end

local function same_ast(a, b)
    if a and b and a.kind == b.kind then
        for k, v in pairs(a) do
            if "table" == type(v) then
                if not same_ast(v, b[k]) then
                    return false
                end
            elseif b[k] ~= v then
                return false
            end
        end
        return true
    end  
    return false
end

local function lex_str(ls)
    if ls.token ~= 'TK_name' and (LJ_52 or ls.token ~= 'TK_goto') then
        err_token(ls, 'TK_name')
    end
    local s = ls.tokenval
    ls:next()
    return s
end

local expr_primary, expr, expr_unop, expr_binop, expr_simple
local expr_list, expr_table
local parse_body, parse_block, parse_args, parse_opt_block

local function var_name(ast, ls)
    local name = lex_str(ls)
    return ast:identifier(name)
end

local function expr_field(ast, ls, v)
    ls:next() -- Skip dot or colon.
    local key = lex_str(ls)
    return ast:expr_property(v, key)
end

local function expr_bracket(ast, ls)
    ls:next() -- Skip '['.
    local v = expr(ast, ls)
    lex_check(ls, ']')
    return v
end

function expr_table(ast, ls)
    local line = ls.linenumber
    local kvs = {}
    lex_check(ls, '{')
    while ls.token ~= '}' do
        lex_indent(ls, true)
        lex_dedent(ls)
        local key
        if ls.token == '[' then
            key = expr_bracket(ast, ls)
            lex_check(ls, '=')
        elseif (ls.token == 'TK_name' or (not LJ_52 and ls.token == 'TK_goto')) and ls:lookahead() == '=' then
            local name = lex_str(ls)
            key = ast:literal(name)
            lex_check(ls, '=')
        elseif ls.token == 'TK_string' and ls:lookahead() == '=' then
            key = ast:literal(ls.tokenval)
            ls:next()
            lex_check(ls, '=')
        end
        local val = expr(ast, ls)
        lex_indent(ls, true)
        lex_dedent(ls)
        if key then
            for i = 1, #kvs do
                local arr = kvs[i]
                if same_ast(arr[2], key) then
                    err_syntax(ls, "duplicate key at position " .. i .. " and " .. (#kvs + 1) .. " in table")
                end
            end
        end
        kvs[#kvs + 1] = { val, key }  -- key can be nil
        if not lex_opt(ls, ',') then
            break
        end
    end
    lex_dedent(ls, true)
    lex_match(ls, '}', '{', line)
    -- leave the last dedent for caller
    --lex_dedent(ls)
    return ast:expr_table(kvs, line)
end

function expr_simple(ast, ls)
    local tk, val = ls.token, ls.tokenval
    local e
    if tk == 'TK_number' then
        e = ast:literal(val)
    elseif tk == 'TK_string' then
        e = ast:literal(val)
    elseif tk == 'TK_longstring' then
        e = ast:longstrliteral(val)
    elseif tk == 'TK_nil' then
        e = ast:literal(nil)
    elseif tk == 'TK_true' then
        e = ast:literal(true)
    elseif tk == 'TK_false' then
        e = ast:literal(false)
    elseif tk == 'TK_dots' then
        if not ls.fs.varargs then
            err_syntax(ls, "cannot use `...` outside a vararg function")
        end
        e = ast:expr_vararg()
    elseif tk == '{' then
        return expr_table(ast, ls)
    elseif tk == '\\' or tk == 'TK_lambda' then
        if tk == '\\' then
            ls:next()
        end
        local curry, args, body, proto = parse_body(ast, ls, ls.linenumber)
        local lambda = ast:expr_function(args, body, proto)
        if curry then
            curry = ast:identifier('curry')
            if not in_scope(ast, ls, curry) then
                err_syntax(ls, curry.name .. "() is required for ~>")
            end
            local cargs = { ast:literal(#args), lambda }
            return ast:expr_function_call(curry, cargs, line)
        end
        return lambda
    elseif tk == 'TK_curry' then
        err_syntax(ls, "no argument to curry with ~>")
    else
        return expr_primary(ast, ls)
    end
    ls:next()
    return e
end

function expr_list(ast, ls, indentable)
    local exps = { }
    exps[1] = expr(ast, ls)
    if indentable then
        lex_indent(ls, true)
    end
    while lex_opt(ls, ',') do
        if indentable then
            lex_indent(ls, true)
            lex_dedent(ls)
        end
        exps[#exps + 1] = expr(ast, ls)
        if indentable then
            lex_indent(ls, true)
            lex_dedent(ls)
        end
    end
    local n = #exps
    if n > 0 then
        exps[n] = ast:set_expr_last(exps[n])
    end
    return exps
end

function expr_unop(ast, ls)
    local tk = ls.token
    if tk == 'TK_not' or tk == '-' or tk == '#' then
        local line = ls.linenumber
        ls:next()
        local v = expr_binop(ast, ls, operator.unary_priority)
        return ast:expr_unop(ls.token2str(tk), v, line)
    else
        return expr_simple(ast, ls)
    end
end

-- Parse binary expressions with priority higher than the limit.
function expr_binop(ast, ls, limit)
    local v = expr_unop(ast, ls)
    local op = ls.token2str(ls.token)
    while operator.is_binop(op) and operator.left_priority(op) > limit do
        local line = ls.linenumber
        ls:next()
        local v2, nextop = expr_binop(ast, ls, operator.right_priority(op))
        v = ast:expr_binop(op, v, v2, line)
        op = nextop
    end
    return v, op
end

function expr(ast, ls)
    return expr_binop(ast, ls, 0) -- Priority 0: parse whole expression.
end

-- Parse primary expression.
function expr_primary(ast, ls)
    local v, vk
    -- Parse prefix expression.
    if ls.token == '(' then
        local line = ls.linenumber
        ls:next()
        vk, v = 'expr', ast:expr_brackets(expr(ast, ls))
        lex_match(ls, ')', '(', line)
    elseif ls.token == 'TK_name' or (not LJ_52 and ls.token == 'TK_goto') then
        vk, v = 'var', var_name(ast, ls)
    else
        err_symbol(ls)
    end
    local key
    while true do -- Parse multiple expression suffixes.
        local line = ls.linenumber
        if ls.token == '.' then
            vk, v = 'indexed', expr_field(ast, ls, v)
         elseif ls.token == '[' then
            key = expr_bracket(ast, ls)
            vk, v = 'indexed', ast:expr_index(v, key)
        elseif ls.token == ':' then
            err_syntax(ls, "use of `:` is not supported")
        elseif ls.token == '(' then -- or ls.token == 'TK_string' or ls.token == '{' then
            local args = parse_args(ast, ls)
            -- if vk is indexed and first argument is @, it is a method call
            if vk == 'indexed' and args[1] and args[1].kind == 'Identifier' and args[1].name == 'self' then
                table.remove(args, 1)
                vk, v = 'call', ast:expr_method_call(v, args, line)
            else
                vk, v = 'call', ast:expr_function_call(v, args, line)
            end
        else
            break
        end
    end
    return v, vk
end

-- Parse statements ----------------------------------------------------

-- Parse 'return' statement.
local function parse_return(ast, ls, line)
    ls:next() -- Skip 'return'.
    lex_opt(ls, 'TK_newline')
    ls.fs.has_return = true
    local exps
    if EndOfBlock[ls.token] then -- or ls.token == ';'
        exps = { }
    else -- Return with one or more values.
        exps = expr_list(ast, ls)
    end
    return ast:return_stmt(exps, line)
end

-- Parse numeric 'for'.
local function parse_for_num(ast, ls, varname, line)
    ast:fscope_begin()
    lex_check(ls, '=')
    local init = expr(ast, ls)
    lex_check(ls, ',')
    local last = expr(ast, ls)
    local step
    if lex_opt(ls, ',') then
        step = expr(ast, ls)
    else
        step = ast:literal(1)
    end
    local var = ast:identifier(varname)
    ast:var_declare(varname)  -- add to scope
    local body = parse_opt_block(ast, ls, line, 'TK_for')
    ast:fscope_end()
    return ast:for_stmt(var, init, last, step, body, line, ls.linenumber)
end

-- Parse 'for' iterator.
local function parse_for_iter(ast, ls, indexname)
    ast:fscope_begin()
    local vars = { ast:identifier(indexname) }
    ast:var_declare(indexname)
    while lex_opt(ls, ',') do
        indexname = lex_str(ls)
        vars[#vars + 1] = ast:identifier(indexname)
        ast:var_declare(indexname)
    end
    lex_check(ls, 'TK_in')
    local line = ls.linenumber
    local exps = expr_list(ast, ls)
    local body = parse_opt_block(ast, ls, line, 'TK_for')
    ast:fscope_end()
    return ast:for_iter_stmt(vars, exps, body, line, ls.linenumber)
end

-- Parse 'for' statement.
local function parse_for(ast, ls, line)
    ls:next()  -- Skip 'for'.
    local varname = lex_str(ls)  -- Get first variable name.
    local stmt
    if ls.token == '=' then
        stmt = parse_for_num(ast, ls, varname, line)
    elseif ls.token == ',' or ls.token == 'TK_in' then
        stmt = parse_for_iter(ast, ls, varname)
    else
        err_syntax(ls, "'=' or 'in' expected")
    end
    return stmt
end

-- Parse function call argument list.
function parse_args(ast, ls)
    local line = ls.linenumber
    lex_check(ls, '(')
    --if not LJ_52 and line ~= ls.lastline then
    --    err_syntax(ls, "ambiguous syntax (function call x new statement)")
    --end
    lex_indent(ls, true)
    local args
    if ls.token ~= ')' then
        args = expr_list(ast, ls, true)
    else
        args = { }
    end
    lex_dedent(ls, true)
    lex_match(ls, ')', '(', line)
    -- leave the last dedent for caller
    --lex_dedent(ls)

    --[[  function call must have parens `()`, in which we allow newlines
    if ls.token == '(' then
        ...
    elseif ls.token == '{' then
        local a = expr_table(ast, ls)
        args = { a }
    elseif ls.token == 'TK_string' then
        local a = ls.tokenval
        ls:next()
        args = { ast:literal(a) }
    elseif ls.token == 'TK_longstring' then
        local a = ls.tokenval
        ls:next()
        args = { ast:longstrliteral(a) }
    else
        err_syntax(ls, "function arguments expected")
    end
    --]]
    return args
end


local function parse_assignment(ast, ls, vlist, var, vk)
    local line = ls.linenumber
    if vk ~= 'var' and vk ~= 'indexed' then
        err_syntax(ls, "syntax error, unexpected " .. ls.token2str(ls.token) or ls.tokenval)
    end
    vlist[#vlist+1] = var
    if lex_opt(ls, ',') then
        local n_var, n_vk = expr_primary(ast, ls)
        return parse_assignment(ast, ls, vlist, n_var, n_vk)
    else -- Parse RHS.
        lex_check(ls, '=')
        if vk == 'var' and not in_scope(ast, ls, var) then
            err_syntax(ls, "undeclared identifier " .. var.name)
        end
        local exps = expr_list(ast, ls)
        return ast:assignment_expr(vlist, exps, line)
    end
end

local function parse_call_assign(ast, ls)
    local var, vk = expr_primary(ast, ls)
    if vk == 'call' then
        return ast:new_statement_expr(var, ls.linenumber)
    else
        local vlist = { }
        return parse_assignment(ast, ls, vlist, var, vk)
    end
end

-- Parse 'var' statement.
local function parse_var(ast, ls)
    local line = ls.linenumber
        local vl = { }
        repeat -- Collect LHS.
            vl[#vl+1] = lex_str(ls)
        until not lex_opt(ls, ',')
        shadow_check(ast, ls, vl)

        local exps
        if lex_opt(ls, '=') then -- Optional RHS.
            exps = expr_list(ast, ls)
        else
            exps = { }
        end
        return ast:local_decl(vl, exps, line)
    --end
end

local function parse_while(ast, ls, line)
    ls:next() -- Skip 'while'.
    ast:fscope_begin()
    local cond = expr(ast, ls)
    local body = parse_opt_block(ast, ls, line, 'TK_while')
    local lastline = ls.linenumber
    ast:fscope_end()
    return ast:while_stmt(cond, body, line, lastline)
end

local function parse_if(ast, ls, line)
    local tests, blocks = { }, { }
    ls:next()
    tests[#tests+1] = expr(ast, ls)
    ast:fscope_begin()
    blocks[1] = parse_opt_block(ast, ls, line, 'TK_if')
    ast:fscope_end()
    local else_branch
    while ls.token == 'TK_else' do
        ls:next()
        if ls.token == 'TK_if' then
            ls:next()
            tests[#tests+1] = expr(ast, ls)
            ast:fscope_begin()
            blocks[#blocks+1] = parse_opt_block(ast, ls, ls.linenumber, 'TK_if')
            ast:fscope_end()
        else
            ast:fscope_begin()
            else_branch = parse_opt_block(ast, ls, ls.linenumber, 'TK_else')
            ast:fscope_end()
            break
        end
    end
    return ast:if_stmt(tests, blocks, else_branch, line)
end

local function parse_do(ast, ls, line)
    ls:next() -- Skip 'do'
    ast:fscope_begin()
    local body = parse_opt_block(ast, ls, line, 'TK_do')
    local lastline = ls.linenumber
    if lex_opt(ls, 'TK_until') then
        local cond = expr(ast, ls) -- until condition.
        ast:fscope_end()
        return ast:repeat_stmt(cond, body, line, lastline)
    else
        ast:fscope_end()
        return ast:do_stmt(body, line, lastline)
    end
end


local function parse_label(ast, ls)
    ls:next() -- Skip '::'.
    local name = lex_str(ls)
    lex_check(ls, 'TK_label')
    -- Recursively parse trailing statements: labels and ';' (Lua 5.2 only).
    while true do
        if ls.token == 'TK_label' then
            parse_label(ast, ls)
        --elseif LJ_52 and ls.token == ';' then
        --    ls:next()
        else
            break
        end
    end
    return ast:label_stmt(name, ls.linenumber)
end

local function parse_goto(ast, ls)
    local line = ls.linenumber
    local name = lex_str(ls)
    return ast:goto_stmt(name, line)
end

-- Parse a statement. Returns the statement itself and a boolean that tells if it
-- must be the last one in a chunk.
local function parse_stmt(ast, ls)
    local line = ls.linenumber
    local stmt
    if ls.token == 'TK_if' then
        stmt = parse_if(ast, ls, line)
    elseif ls.token == 'TK_while' then
        stmt = parse_while(ast, ls, line)
    elseif ls.token == 'TK_do' then
        stmt = parse_do(ast, ls, line)
    elseif ls.token == 'TK_for' then
        stmt = parse_for(ast, ls, line)
    --elseif ls.token == 'TK_repeat' then
    --    stmt = parse_repeat(ast, ls, line)
    --elseif ls.token == 'TK_function' then
    --    stmt = parse_func(ast, ls, line)
    elseif ls.token == 'TK_lambda' or ls.token == 'TK_curry' then
        err_syntax(ls, "lambda must be an expression")
    elseif ls.token == 'TK_var' then
        ls:next()
        stmt = parse_var(ast, ls, line)
    elseif ls.token == 'TK_return' then
        stmt = parse_return(ast, ls, line)
        return stmt, true -- Must be last.
    elseif ls.token == 'TK_break' then
        ls:next()
        stmt = ast:break_stmt(line)
        return stmt, not LJ_52 -- Must be last in Lua 5.1.
    --elseif LJ_52 and ls.token == ';' then
    --    ls:next()
    --    return parse_stmt(ast, ls)
    elseif ls.token == 'TK_label' then
        stmt = parse_label(ast, ls)
    elseif ls.token == 'TK_goto' then
        if LJ_52 or ls:lookahead() == 'TK_name' then
            ls:next()
            stmt = parse_goto(ast, ls)
        end
    end
    -- If here 'stmt' is "nil" then ls.token didn't match any of the previous rules.
    -- Fall back to call/assign rule.
    if not stmt then
        stmt = parse_call_assign(ast, ls)
    end
    return stmt, false
end

-- Parse function definition parameters
local function parse_params(ast, ls)
    local args = { }
    if ls.token ~= 'TK_lambda' and ls.token ~= 'TK_curry' then
        repeat
            if ls.token == 'TK_name' or (not LJ_52 and ls.token == 'TK_goto') then
                local name = lex_str(ls)
                args[#args+1] = ast:var_declare(name)
            elseif ls.token == 'TK_dots' then
                ls:next()
                ls.fs.varargs = true
                args[#args + 1] = ast:expr_vararg()
                break
            else
                err_token(ls, "lambda argument expected")
            end
        until not lex_opt(ls, ',')
    end
    if ls.token == 'TK_lambda' then
        ls:next()
        return false, args
    elseif ls.token == 'TK_curry' then
        if ls.fs.varargs then
            err_syntax(ls, "cannot curry varargs with ~>")
        end
        if #args < 2 then
            err_syntax(ls, "at least 2 arguments needed with ~>")
        end
        ls:next()
        return true, args
    end
    err_token(ls, "->")
end

function parse_block_stmts(ast, ls)
    local firstline = ls.linenumber
    local stmt, islast = nil, false
    local body = { }
    while not islast and not EndOfBlock[ls.token] do
        stmt, islast = parse_stmt(ast, ls)
        body[#body + 1] = stmt
        lex_opt(ls, 'TK_newline')
    end
    return body, firstline, ls.linenumber
end

local function parse_chunk(ast, ls)
    local body, firstline, lastline = parse_block_stmts(ast, ls)
    return ast:chunk(body, ls.chunkname, 0, lastline)
end

-- parse single or indented compound statement
function parse_opt_block(ast, ls, line, match_token)
    local body = {}
    if lex_indent(ls) then
        body = parse_block(ast, ls, line)
        --lex_match(ls, 'TK_dedent', match_token, line)
        if not lex_dedent(ls) then
            ls:error(ls.token, "<dedent> expected to end fn at line %d", line)
        end
    elseif not EndOfBlock[ls.token] and not EmptyFunction[ls.token] then
        -- single statement
        -- this is not worst than C single statement without brace
        body[1] = parse_stmt(ast, ls)
        body.firstline, body.lastline = line, ls.linenumber
    end
    return body
end

-- Parse body of a function
function parse_body(ast, ls, line)
    local pfs = ls.fs
    ls.fs = { varargs = false }
    ast:fscope_begin()
    ls.fs.firstline = line
    local curry, args = parse_params(ast, ls)
    local body = parse_opt_block(ast, ls, line, 'TK_lambda')
    ast:fscope_end()
    local proto = ls.fs
    ls.fs.lastline = ls.linenumber
    ls.fs = pfs
    return curry, args, body, proto
end


function parse_block(ast, ls, firstline)
    --ast:fscope_begin()
    local body = parse_block_stmts(ast, ls)
    body.firstline, body.lastline = firstline, ls.linenumber
    --ast:fscope_end()
    return body
end

local function parse(ast, ls)
    indent = 0
    ls:next()
    lex_opt(ls, 'TK_newline')
    ls.fs = { varargs = false }
    ast:fscope_begin()
    local args = { ast:expr_vararg(ast) }
    local chunk = parse_chunk(ast, ls)
    ast:fscope_end()
    if ls.token == 'TK_dedent' then
        err_syntax(ls, "<dedent> expected near the previous statement/expression")
    elseif ls.token ~= 'TK_eof' then
        err_syntax(ls, "unexpected extra '" .. ls.token2str(ls.token) .. "'")
    end
    assert(indent == 0)
    return chunk
end

return parse
