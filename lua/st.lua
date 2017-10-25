--
-- Generated from st.lt
--

local build = function(kind, node)
    node.kind = kind
    return node
end
local ident = function(name, line)
    return build("Identifier", {name = name, line = line})
end
local AST = {}
AST.chunk = function(body, chunkname, firstline, lastline)
    return build("Chunk", {body = body, chunkname = chunkname, firstline = firstline, lastline = lastline})
end
AST.expr_function = function(args, body, vararg)
    return build("FunctionExpression", {body = body, params = args, vararg = vararg})
end
AST.local_decl = function(lhs, rhs, line)
    return build("LocalDeclaration", {names = lhs, expressions = rhs, line = line})
end
AST.assignment_expr = function(lhs, rhs, line)
    return build("AssignmentExpression", {left = lhs, right = rhs, line = line})
end
AST.expr_index = function(v, index, line)
    return build("MemberExpression", {object = v, property = index, computed = true, line = line})
end
AST.expr_property = function(v, prop, line)
    local index = ident(prop, line)
    return build("MemberExpression", {object = v, property = index, computed = false, line = line})
end
AST.literal = function(val, line)
    return build("Literal", {value = val, line = line})
end
AST.numberliteral = function(val, line)
    return build("NumberLiteral", {value = val, line = line})
end
AST.longstrliteral = function(txt, line)
    return build("LongStringLiteral", {text = txt, line = line})
end
AST.expr_vararg = function()
    return build("Vararg", {})
end
AST.expr_brackets = function(expr)
    expr.bracketed = true
    return expr
end
AST.expr_table = function(keyvals, line)
    return build("Table", {keyvals = keyvals, line = line})
end
AST.expr_unop = function(op, v, line)
    return build("UnaryExpression", {operator = op, argument = v, line = line})
end
local concat_append = function(ts, node)
    local n = #ts
    if node.kind == "ConcatenateExpression" then
        for k = 1, #node.terms do
            ts[n + k] = node.terms[k]
        end
    else
        ts[n + 1] = node
    end
end
AST.expr_binop = function(op, expa, expb, line)
    local binop_body = (op ~= ".." and {operator = op, left = expa, right = expb, line = line})
    if binop_body then
        if op == "and" or op == "or" then
            return build("LogicalExpression", binop_body)
        else
            return build("BinaryExpression", binop_body)
        end
    else
        local terms = {}
        concat_append(terms, expa)
        concat_append(terms, expb)
        return build("ConcatenateExpression", {terms = terms, line = expa.line})
    end
end
AST.identifier = function(name, line)
    return ident(name, line)
end
AST.expr_method_call = function(v, key, args, line)
    local m = ident(key, line)
    return build("SendExpression", {receiver = v, method = m, arguments = args, line = line})
end
AST.expr_function_call = function(v, args, line)
    return build("CallExpression", {callee = v, arguments = args, line = line})
end
AST.return_stmt = function(exps, line)
    return build("ReturnStatement", {arguments = exps, line = line})
end
AST.break_stmt = function(line)
    return build("BreakStatement", {line = line})
end
AST.label_stmt = function(name, line)
    return build("LabelStatement", {label = name, line = line})
end
AST.new_statement_expr = function(expr, line)
    return build("ExpressionStatement", {expression = expr, line = line})
end
AST.if_stmt = function(tests, cons, else_branch, line)
    return build("IfStatement", {tests = tests, cons = cons, alternate = else_branch, line = line})
end
AST.do_stmt = function(body, line, lastline)
    return build("DoStatement", {body = body, line = line, lastline = lastline})
end
AST.while_stmt = function(test, body, line, lastline)
    return build("WhileStatement", {test = test, body = body, line = line, lastline = lastline})
end
AST.repeat_stmt = function(test, body, line, lastline)
    return build("RepeatStatement", {test = test, body = body, line = line, lastline = lastline})
end
AST.for_stmt = function(variable, init, last, step, body, line, lastline)
    local for_init = build("ForInit", {id = variable, value = init, line = line})
    return build("ForStatement", {init = for_init, last = last, step = step, body = body, line = line, lastline = lastline})
end
AST.for_iter_stmt = function(vars, exps, body, line, lastline)
    local names = build("ForNames", {names = vars, line = line})
    return build("ForInStatement", {namelist = names, explist = exps, body = body, line = line, lastline = lastline})
end
AST.goto_stmt = function(name, line)
    return build("GotoStatement", {label = name, line = line})
end
local same
same = function(a, b)
    if a and b and a.kind == b.kind then
        local last = 1
        if #a ~= #b then
            return false
        end
        for i, v in ipairs(a) do
            last = i
            if "table" == type(v) then
                if not same(v, b[i]) then
                    return false
                end
            elseif b[i] ~= v then
                return false
            end
        end
        for k, v in pairs(a) do
            if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
                if "table" == type(v) then
                    if not same(v, b[k]) then
                        return false
                    end
                elseif b[k] ~= v then
                    return false
                end
            end
        end
        for k, v in pairs(b) do
            if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
                if "table" == type(v) then
                    if not same(v, a[k]) then
                        return false
                    end
                elseif a[k] ~= v then
                    return false
                end
            end
        end
        return true
    end
    return false
end
AST.same = same
return AST