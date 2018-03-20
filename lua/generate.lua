--
-- Generated from generate.lt
--

local reserved = require("lua.reserved")
local operator = require("lua.operator")
local chars = require("lua.chars")
local Keyword = reserved.Keyword
local format = string.format
local is = chars.is
local generate = function(tree)
    local StatementRule = {}
    local ExpressionRule = {}
    local proto = nil
    local proto_enter = function(indent)
        local ind = 0
        if indent then
            ind = indent
        elseif proto then
            ind = proto.indent
        end
        proto = {code = {}, indent = ind, parent = proto}
    end
    local proto_leave = function()
        proto = proto.parent
    end
    local indent_more = function()
        proto.indent = proto.indent + 1
    end
    local indent_less = function()
        proto.indent = proto.indent - 1
    end
    local proto_inline = function()
        if #proto.code > 0 then
            proto.code[1] = string.gsub(proto.code[1], "^%s*", "")
        end
        return table.concat(proto.code, "\n")
    end
    local proto_merge = function(child)
        for k = 1, #child.code do
            local line = child.code[k]
            local indent_str = string.rep("    ", proto.indent)
            proto.code[#proto.code + 1] = indent_str .. line
        end
    end
    local expr_emit = function(node)
        local rule = ExpressionRule[node.kind]
        if rule then
            return rule(node)
        end
        error("cannot find an expression rule for " .. node.kind)
    end
    local emit = function(node)
        local rule = StatementRule[node.kind]
        if rule then
            return rule(node)
        end
        error("cannot find a statement rule for " .. node.kind)
    end
    local to_expr = function(node, bracket)
        local val = expr_emit(node)
        if bracket then
            return "(" .. val .. ")"
        end
        return val
    end
    local expr_list = function(exps)
        local strls = {}
        local last = #exps
        for k = 1, last do
            strls[k] = to_expr(exps[k], k == last and exps[k].bracketed)
        end
        return table.concat(strls, ", ")
    end
    local list_emit = function(node_list)
        for i = 1, #node_list do
            emit(node_list[i])
        end
    end
    local add_line = function(line)
        local indent = string.rep("    ", proto.indent)
        proto.code[#proto.code + 1] = indent .. line
    end
    local add_section = function(header, body, omit_end)
        add_line(header)
        indent_more()
        list_emit(body)
        indent_less()
        if not omit_end then
            add_line("end")
        end
    end
    local is_string = function(node)
        return node.kind == "Literal" and type(node.value) == "string"
    end
    local is_const = function(node, val)
        return node.kind == "Literal" and node.value == val
    end
    local is_literal = function(node)
        local k = node.kind
        return (k == "Literal" or k == "Table")
    end
    local string_is_ident = function(str)
        local c = string.sub(str, 1, 1)
        if c == "" or not is.letter(c) then
            return false
        end
        for k = 2, #str do
            c = string.sub(str, k, k)
            if not is.letter(c) and not is.digit(c) then
                return false
            end
        end
        return not Keyword[str]
    end
    local comma_sep_list = function(ls, f)
        local strls
        if f then
            strls = {}
            for k = 1, #ls do
                strls[k] = f(ls[k])
            end
        else
            strls = ls
        end
        return table.concat(strls, ", ")
    end
    local as_parameter = function(node)
        return node.kind == "Vararg" and "..." or node.name
    end
    ExpressionRule.Identifier = function(node)
        return node.name, operator.ident_priority
    end
    local escape = function(s)
        local replace = {["\""] = [[\"]], ["\a"] = [[\a]], ["\b"] = [[\b]], ["\f"] = [[\f]], ["\n"] = [[\n]], ["\r"] = [[\r]], ["\t"] = [[\t]], ["\v"] = [[\v]]}
        return string.gsub(s, "[\"\a\b\f\n\r\t\v]", replace)
    end
    ExpressionRule.Literal = function(node)
        local val = node.value
        local str = type(val) == "string" and format("\"%s\"", escape(val)) or tostring(val)
        return str, operator.ident_priority
    end
    ExpressionRule.NumberLiteral = function(node)
        return node.value, operator.ident_priority
    end
    ExpressionRule.LongStringLiteral = function(node)
        local n, m = string.find(node.text, "^`+")
        if n then
            local p, q = string.find(node.text, "`+$")
            assert(q - p == m - n)
            local eq = string.rep("=", m - n)
            local begins = "[" .. eq .. "["
            local ends = "]" .. eq .. "]"
            local text = string.sub(node.text, m + 1, p - 1)
            return begins .. text .. ends, operator.ident_priority
        end
        return node.text, operator.ident_priority
    end
    ExpressionRule.MemberExpression = function(node)
        local object, prio = expr_emit(node.object)
        if prio < operator.ident_priority or is_literal(node.object) then
            object = "(" .. object .. ")"
        end
        local exp
        if node.computed then
            local prop = expr_emit(node.property)
            exp = format("%s[%s]", object, prop)
        else
            exp = format("%s.%s", object, node.property.name)
        end
        return exp, operator.ident_priority
    end
    ExpressionRule.Vararg = function()
        return "...", operator.ident_priority
    end
    ExpressionRule.BinaryExpression = function(node)
        local oper = node.operator
        local lprio = operator.left_priority(oper)
        local rprio = operator.right_priority(oper)
        local a, alprio, arprio = expr_emit(node.left)
        local b, blprio, brprio = expr_emit(node.right)
        if not arprio then
            arprio = alprio
        end
        if not brprio then
            brprio = blprio
        end
        local ap = arprio < lprio and format("(%s)", a) or a
        local bp = blprio <= rprio and format("(%s)", b) or b
        return format("%s %s %s", ap, oper, bp), lprio, rprio
    end
    ExpressionRule.UnaryExpression = function(node)
        local arg, arg_prio = expr_emit(node.argument)
        local op_prio = operator.unary_priority
        if arg_prio < op_prio then
            arg = format("(%s)", arg)
        end
        local op = node.operator
        if op == "not" then
            op = "not "
        end
        return format("%s%s", op, arg), operator.unary_priority
    end
    ExpressionRule.LogicalExpression = ExpressionRule.BinaryExpression
    ExpressionRule.ConcatenateExpression = function(node)
        local ls = {}
        local cat_prio = operator.left_priority("..")
        for k = 1, #node.terms do
            local kprio
            ls[k], kprio = expr_emit(node.terms[k])
            if kprio < cat_prio then
                ls[k] = format("(%s)", ls[k])
            end
        end
        return table.concat(ls, " .. "), cat_prio
    end
    ExpressionRule.Table = function(node)
        local hash = {}
        local last = #node.keyvals
        for i = 1, last do
            local kv = node.keyvals[i]
            local val = expr_emit(kv[1])
            local key = kv[2]
            if key then
                if is_string(key) and string_is_ident(key.value) then
                    hash[i] = format("%s = %s", key.value, val)
                else
                    hash[i] = format("[%s] = %s", expr_emit(key), val)
                end
            else
                if i == last and kv[1].bracketed then
                    hash[i] = format("(%s)", val)
                else
                    hash[i] = format("%s", val)
                end
            end
        end
        local content = ""
        if #hash > 0 then
            content = comma_sep_list(hash)
        end
        return "{" .. content .. "}", operator.ident_priority
    end
    ExpressionRule.CallExpression = function(node)
        local callee, prio = expr_emit(node.callee)
        if prio < operator.ident_priority then
            callee = "(" .. callee .. ")"
        end
        local exp = format("%s(%s)", callee, expr_list(node.arguments))
        return exp, operator.ident_priority
    end
    ExpressionRule.SendExpression = function(node)
        local receiver, prio = expr_emit(node.receiver)
        if prio < operator.ident_priority or is_literal(node.receiver) then
            receiver = "(" .. receiver .. ")"
        end
        local method = node.method.name
        local exp = format("%s:%s(%s)", receiver, method, expr_list(node.arguments))
        return exp, operator.ident_priority
    end
    ExpressionRule.FunctionExpression = function(node)
        proto_enter()
        local header = format("function(%s)", comma_sep_list(node.params, as_parameter))
        add_section(header, node.body)
        local code = proto_inline()
        proto_leave()
        return code, 0
    end
    StatementRule.CallExpression = function(node)
        local line = expr_emit(node)
        add_line(line)
    end
    StatementRule.ForStatement = function(node)
        local init = node.init
        local istart = expr_emit(init.value)
        local iend = expr_emit(node.last)
        local header
        if node.step and not is_const(node.step, 1) then
            local step = expr_emit(node.step)
            header = format("for %s = %s, %s, %s do", init.id.name, istart, iend, step)
        else
            header = format("for %s = %s, %s do", init.id.name, istart, iend)
        end
        add_section(header, node.body)
    end
    StatementRule.ForInStatement = function(node)
        local vars = comma_sep_list(node.namelist.names, as_parameter)
        local explist = expr_list(node.explist)
        local header = format("for %s in %s do", vars, explist)
        add_section(header, node.body)
    end
    StatementRule.DoStatement = function(node)
        add_section("do", node.body)
    end
    StatementRule.WhileStatement = function(node)
        local test = expr_emit(node.test)
        local header = format("while %s do", test)
        add_section(header, node.body)
    end
    StatementRule.RepeatStatement = function(node)
        add_section("repeat", node.body, true)
        local test = expr_emit(node.test)
        local until_line = format("until %s", test)
        add_line(until_line)
    end
    StatementRule.BreakStatement = function()
        add_line("break")
    end
    StatementRule.IfStatement = function(node)
        local ncons = #node.tests
        for i = 1, ncons do
            local header_tag = i == 1 and "if" or "elseif"
            local test = expr_emit(node.tests[i])
            local header = format("%s %s then", header_tag, test)
            add_section(header, node.cons[i], true)
        end
        if node.alternate then
            add_section("else", node.alternate, true)
        end
        add_line("end")
    end
    StatementRule.LocalDeclaration = function(node)
        local line
        local names = comma_sep_list(node.names, as_parameter)
        if #node.expressions > 0 then
            line = format("local %s = %s", names, expr_list(node.expressions))
        else
            line = format("local %s", names)
        end
        add_line(line)
    end
    StatementRule.AssignmentExpression = function(node)
        local line = format("%s = %s", expr_list(node.left), expr_list(node.right))
        add_line(line)
    end
    StatementRule.Chunk = function(node)
        list_emit(node.body)
    end
    StatementRule.ExpressionStatement = function(node)
        local line = expr_emit(node.expression)
        add_line(line)
    end
    StatementRule.ReturnStatement = function(node)
        local line = format("return %s", expr_list(node.arguments))
        add_line(line)
    end
    StatementRule.LabelStatement = function(node)
        add_line("::" .. node.label .. "::")
    end
    StatementRule.GotoStatement = function(node)
        add_line("goto " .. node.label)
    end
    proto_enter()
    emit(tree)
    local code = proto_inline()
    proto_leave()
    return code
end
return generate