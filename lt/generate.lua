--
-- Generated from generate.lt
--

local operator = require("lt.operator")
local Keyword = require("lt.reserved")
local strbyte, strsub = string.byte, string.sub
local ASCII_0, ASCII_9 = 48, 57
local ASCII_a, ASCII_z = 97, 122
local ASCII_A, ASCII_Z = 65, 90
local char_isletter = function(c)
    local b = strbyte(c)
    if b >= ASCII_a and b <= ASCII_z then
        return true
    elseif b >= ASCII_A and b <= ASCII_Z then
        return true
    else
        return c == "_"
    end
end
local char_isdigit = function(c)
    local b = strbyte(c)
    return b >= ASCII_0 and b <= ASCII_9
end
local StatementRule = {}
local ExpressionRule = {}
local concat = table.concat
local format = string.format
local is_string = function(node)
    return node.kind == "Literal" and type(node.value) == "string"
end
local is_const = function(node, val)
    return node.kind == "Literal" and node.value == val
end
local is_literal = function(node)
    local k = node.kind
    return k == "Literal" or k == "Table"
end
local string_is_ident = function(str)
    local c = strsub(str, 1, 1)
    if c == "" or not char_isletter(c) then
        return false
    end
    for k = 2, #str do
        c = strsub(str, k, k)
        if not char_isletter(c) and not char_isdigit(c) then
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
    return concat(strls, ", ")
end
local as_parameter = function(node)
    return node.kind == "Vararg" and "..." or node.name
end
ExpressionRule.Identifier = function(self, node)
    return node.name, operator.ident_priority
end
local escape = function(s)
    local replace = {["\""] = [[\"]], ["\a"] = [[\a]], ["\b"] = [[\b]], ["\f"] = [[\f]], ["\n"] = [[\n]], ["\r"] = [[\r]], ["\t"] = [[\t]], ["\v"] = [[\v]]}
    return string.gsub(s, "[\"\a\b\f\n\r\t\v]", replace)
end
ExpressionRule.Literal = function(self, node)
    local val = node.value
    local str = type(val) == "string" and format("\"%s\"", escape(val)) or tostring(val)
    return str, operator.ident_priority
end
ExpressionRule.NumberLiteral = function(self, node)
    return node.value, operator.ident_priority
end
ExpressionRule.LongStringLiteral = function(self, node)
    return node.text, operator.ident_priority
end
ExpressionRule.MemberExpression = function(self, node)
    local object, prio = self:expr_emit(node.object)
    if prio < operator.ident_priority or is_literal(node.object) then
        object = "(" .. object .. ")"
    end
    local exp
    if node.computed then
        local prop = self:expr_emit(node.property)
        exp = format("%s[%s]", object, prop)
    else
        exp = format("%s.%s", object, node.property.name)
    end
    return exp, operator.ident_priority
end
ExpressionRule.Vararg = function(self)
    return "...", operator.ident_priority
end
ExpressionRule.ExpressionValue = function(self, node)
    return "(" .. self:expr_emit(node.value) .. ")"
end
ExpressionRule.BinaryExpression = function(self, node)
    local oper = node.operator
    local lprio = operator.left_priority(oper)
    local rprio = operator.right_priority(oper)
    local a, alprio, arprio = self:expr_emit(node.left)
    local b, blprio, brprio = self:expr_emit(node.right)
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
ExpressionRule.UnaryExpression = function(self, node)
    local arg, arg_prio = self:expr_emit(node.argument)
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
ExpressionRule.ConcatenateExpression = function(self, node)
    local ls = {}
    local cat_prio = operator.left_priority("..")
    for k = 1, #node.terms do
        local kprio
        ls[k], kprio = self:expr_emit(node.terms[k])
        if kprio < cat_prio then
            ls[k] = format("(%s)", ls[k])
        end
    end
    return concat(ls, " .. "), cat_prio
end
ExpressionRule.Table = function(self, node)
    local hash = {}
    for i = 1, #node.keyvals do
        local kv = node.keyvals[i]
        local val = self:expr_emit(kv[1])
        local key = kv[2]
        if key then
            if is_string(key) and string_is_ident(key.value) then
                hash[i] = format("%s = %s", key.value, val)
            else
                hash[i] = format("[%s] = %s", self:expr_emit(key), val)
            end
        else
            hash[i] = format("%s", val)
        end
    end
    local content = ""
    if #hash > 0 then
        content = comma_sep_list(hash)
    end
    return "{" .. content .. "}", operator.ident_priority
end
ExpressionRule.CallExpression = function(self, node)
    local callee, prio = self:expr_emit(node.callee)
    if prio < operator.ident_priority then
        callee = "(" .. callee .. ")"
    end
    local exp = format("%s(%s)", callee, self:expr_list(node.arguments))
    return exp, operator.ident_priority
end
ExpressionRule.SendExpression = function(self, node)
    local callee, prio = self:expr_emit(node.callee)
    local dot = string.match(callee, ".*%.()")
    local method = callee:sub(1, dot - 2) .. ":" .. callee:sub(dot)
    if prio < operator.ident_priority or is_literal(node.callee) then
        method = "(" .. method .. ")"
    end
    local exp = format("%s(%s)", method, self:expr_list(node.arguments))
    return exp, operator.ident_priority
end
StatementRule.FunctionDeclaration = function(self, node)
    self:proto_enter(0)
    local name = ""
    if node.id then
        name = self:expr_emit(node.id)
    end
    local header = format("function %s(%s)", name, comma_sep_list(node.params, as_parameter))
    if node.locald then
        header = "local " .. header
    end
    self:add_section(header, node.body)
    local child_proto = self:proto_leave()
    self.proto:merge(child_proto)
end
ExpressionRule.FunctionExpression = function(self, node)
    self:proto_enter()
    local header = format("function(%s)", comma_sep_list(node.params, as_parameter))
    self:add_section(header, node.body)
    local child_proto = self:proto_leave()
    return child_proto:inline(), 0
end
StatementRule.CallExpression = function(self, node)
    local line = self:expr_emit(node)
    self:add_line(line)
end
StatementRule.ForStatement = function(self, node)
    local init = node.init
    local istart = self:expr_emit(init.value)
    local iend = self:expr_emit(node.last)
    local header
    if node.step and not is_const(node.step, 1) then
        local step = self:expr_emit(node.step)
        header = format("for %s = %s, %s, %s do", init.id.name, istart, iend, step)
    else
        header = format("for %s = %s, %s do", init.id.name, istart, iend)
    end
    self:add_section(header, node.body)
end
StatementRule.ForInStatement = function(self, node)
    local vars = comma_sep_list(node.namelist.names, as_parameter)
    local explist = self:expr_list(node.explist)
    local header = format("for %s in %s do", vars, explist)
    self:add_section(header, node.body)
end
StatementRule.DoStatement = function(self, node)
    self:add_section("do", node.body)
end
StatementRule.WhileStatement = function(self, node)
    local test = self:expr_emit(node.test)
    local header = format("while %s do", test)
    self:add_section(header, node.body)
end
StatementRule.RepeatStatement = function(self, node)
    self:add_section("repeat", node.body, true)
    local test = self:expr_emit(node.test)
    local until_line = format("until %s", test)
    self:add_line(until_line)
end
StatementRule.BreakStatement = function(self)
    self:add_line("break")
end
StatementRule.IfStatement = function(self, node)
    local ncons = #node.tests
    for i = 1, ncons do
        local header_tag = i == 1 and "if" or "elseif"
        local test = self:expr_emit(node.tests[i])
        local header = format("%s %s then", header_tag, test)
        self:add_section(header, node.cons[i], true)
    end
    if node.alternate then
        self:add_section("else", node.alternate, true)
    end
    self:add_line("end")
end
StatementRule.LocalDeclaration = function(self, node)
    local line
    local names = comma_sep_list(node.names, as_parameter)
    if #node.expressions > 0 then
        line = format("local %s = %s", names, self:expr_list(node.expressions))
    else
        line = format("local %s", names)
    end
    self:add_line(line)
end
StatementRule.AssignmentExpression = function(self, node)
    local line = format("%s = %s", self:expr_list(node.left), self:expr_list(node.right))
    self:add_line(line)
end
StatementRule.Chunk = function(self, node)
    self:list_emit(node.body)
end
StatementRule.ExpressionStatement = function(self, node)
    local line = self:expr_emit(node.expression)
    self:add_line(line)
end
StatementRule.ReturnStatement = function(self, node)
    local line = format("return %s", self:expr_list(node.arguments))
    self:add_line(line)
end
StatementRule.LabelStatement = function(self, node)
    self:add_line("::" .. node.label .. "::")
end
StatementRule.GotoStatement = function(self, node)
    self:add_line("goto " .. node.label)
end
local proto_inline = function(proto)
    if #proto.code > 0 then
        proto.code[1] = string.gsub(proto.code[1], "^%s*", "")
    end
    return concat(proto.code, "\n")
end
local proto_merge = function(proto, child)
    for k = 1, #child.code do
        local line = child.code[k]
        local indent_str = string.rep("    ", proto.indent)
        proto.code[#proto.code + 1] = indent_str .. line
    end
end
local proto_new = function(parent, indent)
    local ind = 0
    if indent then
        ind = indent
    elseif parent then
        ind = parent.indent
    end
    local proto = {code = {}, indent = ind, parent = parent}
    proto.inline = proto_inline
    proto.merge = proto_merge
    return proto
end
local generate = function(tree)
    local self = {line = 0}
    self.proto = proto_new()
    self.chunkname = tree.chunkname
    self.proto_enter = function(self, indent)
        self.proto = proto_new(self.proto, indent)
    end
    self.proto_leave = function(self)
        local proto = self.proto
        self.proto = proto.parent
        return proto
    end
    local to_expr = function(node)
        return self:expr_emit(node)
    end
    self.compile_code = function(self)
        return concat(self.code, "\n")
    end
    self.indent_more = function(self)
        local proto = self.proto
        proto.indent = proto.indent + 1
    end
    self.indent_less = function(self)
        local proto = self.proto
        proto.indent = proto.indent - 1
    end
    self.line = function(self, line)
    end
    self.add_line = function(self, line)
        local proto = self.proto
        local indent = string.rep("    ", proto.indent)
        proto.code[#proto.code + 1] = indent .. line
    end
    self.add_section = function(self, header, body, omit_end)
        self:add_line(header)
        self:indent_more()
        self:list_emit(body)
        self:indent_less()
        if not omit_end then
            self:add_line("end")
        end
    end
    self.expr_emit = function(self, node)
        local rule = ExpressionRule[node.kind]
        if not rule then
            error("cannot find an expression rule for " .. node.kind)
        end
        return rule(self, node)
    end
    self.expr_list = function(self, exps)
        return comma_sep_list(exps, to_expr)
    end
    self.emit = function(self, node)
        local rule = StatementRule[node.kind]
        if not rule then
            error("cannot find a statement rule for " .. node.kind)
        end
        rule(self, node)
        if node.line then
            self:line(node.line)
        end
    end
    self.list_emit = function(self, node_list)
        for i = 1, #node_list do
            self:emit(node_list[i])
        end
    end
    self:emit(tree)
    return self:proto_leave():inline()
end
return generate