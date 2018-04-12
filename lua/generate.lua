--
-- Generated from generate.lt
--

local Tag = require("lua.tag")
local reserved = require("lua.reserved")
local operator = require("lua.operator")
local chars = require("lua.chars")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local Keyword = reserved.Keyword
local format = string.format
local concat = table.concat
local is = chars.is
local generate = function(stmts)
    local Stmt = {}
    local Expr = {}
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
        return concat(proto.code, "\n")
    end
    local emit = function(node)
        local rule = Stmt[node.tag]
        if rule then
            return rule(node)
        end
        error("cannot find a statement rule for " .. (node.tag or "nil"))
    end
    local list_emit = function(node_list)
        for i = 1, #node_list do
            emit(node_list[i])
        end
    end
    local expr_emit = function(node)
        local rule = Expr[node.tag]
        if rule then
            return rule(node)
        end
        error("cannot find an expression rule for " .. (node.tag or "nil"))
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
        return concat(strls, ", ")
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
    local is_plain_string = function(node)
        if node.tag == TExpr.String and type(node.value) == "string" then
            local str = node.value
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
    end
    local comma_sep_list = function(ls, f)
        local strls = ls
        if f then
            strls = {}
            for k = 1, #ls do
                strls[k] = f(ls[k])
            end
        end
        return concat(strls, ", ")
    end
    local as_parameter = function(node)
        return node.tag == TExpr.Vararg and "..." or node.name
    end
    local priority = function(val)
        return val, operator.ident_priority
    end
    Expr[TExpr.Id] = function(node)
        return priority(node.name)
    end
    Expr[TExpr.Number] = function(node)
        return priority(node.value)
    end
    Expr[TExpr.Bool] = function(node)
        return priority(tostring(node.value))
    end
    Expr[TExpr.Nil] = function()
        return priority("nil")
    end
    Expr[TExpr.Vararg] = function()
        return priority("...")
    end
    local escape = function(s)
        local replace = {["\""] = [[\"]], ["\a"] = [[\a]], ["\b"] = [[\b]], ["\f"] = [[\f]], ["\n"] = [[\n]], ["\r"] = [[\r]], ["\t"] = [[\t]], ["\v"] = [[\v]]}
        return string.gsub(s, "[\"\a\b\f\n\r\t\v]", replace)
    end
    Expr[TExpr.String] = function(node)
        local val = node.value
        local text = val
        if node.long then
            local n, m = string.find(val, "^`+")
            if n then
                local p, q = string.find(val, "`+$")
                assert(q - p == m - n)
                local eq = string.rep("=", m - n)
                local ls = {"[", eq, "[", string.sub(val, m + 1, p - 1), "]", eq, "]"}
                text = priority(concat(ls))
            end
        else
            text = format("\"%s\"", escape(val))
        end
        return priority(text)
    end
    Expr[TExpr.Function] = function(node)
        proto_enter()
        local header = format("function(%s)", comma_sep_list(node.params, as_parameter))
        add_section(header, node.body)
        local code = proto_inline()
        proto_leave()
        return code, 0
    end
    Expr[TExpr.Table] = function(node)
        local hash = {}
        local last = #node.keyvals
        for i = 1, last do
            local kv = node.keyvals[i]
            local val = expr_emit(kv[1])
            local key = kv[2]
            if key then
                if is_plain_string(key) then
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
        return priority("{" .. content .. "}")
    end
    local receiver = function(target)
        local obj, prio = expr_emit(target)
        local t = target.tag
        if prio < operator.ident_priority or t == TExpr.String or t == TExpr.Number or t == TExpr.Bool or t == TExpr.Table then
            return "(" .. obj .. ")"
        end
        return obj
    end
    Expr[TExpr.Index] = function(node)
        local exp = format("%s[%s]", receiver(node.obj), expr_emit(node.idx))
        return priority(exp)
    end
    Expr[TExpr.Property] = function(node)
        local exp = format("%s.%s", receiver(node.obj), node.prop)
        return priority(exp)
    end
    Expr[TExpr.Invoke] = function(node)
        local exp = format("%s:%s(%s)", receiver(node.obj), node.prop, expr_list(node.args))
        return priority(exp)
    end
    Expr[TExpr.Call] = function(node)
        local exp = format("%s(%s)", receiver(node.func), expr_list(node.args))
        return priority(exp)
    end
    Expr[TExpr.Unary] = function(node)
        local arg, arg_prio = expr_emit(node.left)
        local op_prio = operator.unary_priority
        if arg_prio < op_prio then
            arg = format("(%s)", arg)
        end
        local op = node.op
        if op == "not" then
            op = "not "
        end
        return format("%s%s", op, arg), operator.unary_priority
    end
    Expr[TExpr.Binary] = function(node)
        local oper = node.op
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
    Stmt[TStmt.Expr] = function(node)
        local line = expr_emit(node.expr)
        add_line(line)
    end
    Stmt[TStmt.Local] = function(node)
        local line
        local vars = comma_sep_list(node.vars, as_parameter)
        if #node.exprs > 0 then
            line = format("local %s = %s", vars, expr_list(node.exprs))
        else
            line = format("local %s", vars)
        end
        add_line(line)
    end
    Stmt[TStmt.Assign] = function(node)
        local line = format("%s = %s", expr_list(node.lefts), expr_list(node.rights))
        add_line(line)
    end
    Stmt[TStmt.Do] = function(node)
        add_section("do", node.body)
    end
    Stmt[TStmt.If] = function(node)
        local ncons = #node.tests
        for i = 1, ncons do
            local header_tag = i == 1 and "if" or "elseif"
            local test = expr_emit(node.tests[i])
            local header = format("%s %s then", header_tag, test)
            add_section(header, node.thenss[i], true)
        end
        if node.elses then
            add_section("else", node.elses, true)
        end
        add_line("end")
    end
    Stmt[TStmt.Forin] = function(node)
        local vars = comma_sep_list(node.vars, as_parameter)
        local explist = expr_list(node.exprs)
        local header = format("for %s in %s do", vars, explist)
        add_section(header, node.body)
    end
    Stmt[TStmt.Fornum] = function(node)
        local istart = expr_emit(node.first)
        local iend = expr_emit(node.last)
        local header
        if node.step then
            if not (node.step.tag == TExpr.Number and node.step.value == 1) then
                local step = expr_emit(node.step)
                header = format("for %s = %s, %s, %s do", node.var.name, istart, iend, step)
            end
        end
        if not header then
            header = format("for %s = %s, %s do", node.var.name, istart, iend)
        end
        add_section(header, node.body)
    end
    Stmt[TStmt.While] = function(node)
        local test = expr_emit(node.test)
        local header = format("while %s do", test)
        add_section(header, node.body)
    end
    Stmt[TStmt.Repeat] = function(node)
        add_section("repeat", node.body, true)
        local test = expr_emit(node.test)
        local until_line = format("until %s", test)
        add_line(until_line)
    end
    Stmt[TStmt.Return] = function(node)
        local line = format("return %s", expr_list(node.exprs))
        add_line(line)
    end
    Stmt[TStmt.Break] = function()
        add_line("break")
    end
    Stmt[TStmt.Goto] = function(node)
        add_line("goto " .. node.name)
    end
    Stmt[TStmt.Label] = function(node)
        add_line("::" .. node.name .. "::")
    end
    proto_enter()
    list_emit(stmts)
    local code = proto_inline()
    proto_leave()
    return code
end
return generate