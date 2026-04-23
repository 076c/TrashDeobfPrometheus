local Ast = require("./../prometheus/ast")
local VisitAst = require("./../prometheus/visitast")

--[[
propagate_fenv_access():

    const_map = {}

    for each node in AST:
        if node is LocalVariableDeclaration or AssignmentStatement:
            for each (var = expr):
                if expr is StringExpression or NumberExpression or BooleanExpression or NilExpression:
                    const_map[var.scope][var.id] = expr.value

                else if expr is VariableExpression:
                    if expr in const_map:
                        const_map[var.scope][var.id] = const_map[expr.scope][expr.id]


    for each node in AST:
        if node is IndexExpression:
            if node.base is VariableExpression and base.id == "_ENV":

                key = node.index

                if key is VariableExpression and key in const_map:
                    key = const_map[key.scope][key.id]

                if key is String or Number:
                    node = GlobalExpression(key)


    for each node in AST:
        if node is AssignmentStatement:
            if rhs is pure:
                replace uses of lhs variables with rhs
]]

return function(ast)
	local def_map = {}

	VisitAst(ast, nil, function(node)
		if node.kind == "AssignmentStatement" then
			local var, value = node.lhs[1], node.rhs[1]

			if var.kind ~= "VariableExpression" and var.kind ~= "AssignmentVariable" then
				return
			end

			if def_map[var.scope] == nil then
				def_map[var.scope] = {}
			end

			def_map[var.scope][var.id] = value
		elseif node.kind == "LocalVariableDeclaration" then
			local exprs = node.expressions
			local ids = node.ids

			local scope = node.scope

			def_map[scope] = def_map[scope] or {}

			for i, id in ipairs(ids) do
				def_map[scope][id] = exprs[i]
			end
		end
	end)

	local fenv_global_scope, fenv_global_id

	VisitAst(ast, nil, function(node)
		if node.kind == "AssignmentStatement" then
			local var, val = node.lhs[1], node.rhs[1]

			if val.kind == "OrExpression" then
				if val.rhs.kind == "VariableExpression" and val.rhs.scope:getVariableName(val.rhs.id) == "_ENV" then
					fenv_global_scope, fenv_global_id = var.scope, var.id
				end
			end
		end
	end)

	if not fenv_global_scope or not fenv_global_id then
		return
	end

	local pureCache = {}

	local function has_side_effects(expr)
		if type(expr) ~= "table" then
			return false
		end

		if pureCache[expr] ~= nil then
			return pureCache[expr]
		end

		local kind = expr.kind
		local result = true

		if
			kind == Ast.AstKind.NumberExpression
			or kind == Ast.AstKind.StringExpression
			or kind == Ast.AstKind.BooleanExpression
			or kind == Ast.AstKind.NilExpression
		then
			result = false

		elseif kind == Ast.AstKind.VariableExpression
			or kind == Ast.AstKind.GlobalExpression
		then
			result = false

		elseif Ast.astKindExpressionToNumber(kind) > 0 then
			result =
				has_side_effects(expr.lhs) or has_side_effects(expr.rhs)

		elseif
			kind == Ast.AstKind.NotExpression
			or kind == Ast.AstKind.NegateExpression
			or kind == Ast.AstKind.LenExpression
		then
			result = has_side_effects(expr.rhs)

		elseif
			kind == Ast.AstKind.FunctionCallExpression
			or kind == Ast.AstKind.PassSelfFunctionCallExpression
		then
			result = true

		elseif kind == Ast.AstKind.IndexExpression then
			result =
				has_side_effects(expr.base)
				or has_side_effects(expr.index)

		elseif kind == Ast.AstKind.TableConstructorExpression then
			for _, entry in ipairs(expr.entries or {}) do
				if entry.key and has_side_effects(entry.key) then
					result = true
					break
				end
				if has_side_effects(entry.value) then
					result = true
					break
				end
			end
			if not result then
				result = false
			end

		elseif kind == Ast.AstKind.IfElseExpression then
			result =
				has_side_effects(expr.condition)
				or has_side_effects(expr.true_expr)
				or has_side_effects(expr.false_expr)

		elseif kind == Ast.AstKind.FunctionLiteralExpression then
			result = true

		elseif kind == Ast.AstKind.VarargExpression then
			result = true

		else
			result = true
		end

		pureCache[expr] = result
		return result
	end

	--VisitAst(ast, nil, function(node)
	--	if node.kind == "AssignmentStatement" then
	--		local expr = node.rhs[1]
	--
	--		print(expr.kind)
	--
	--		if not has_side_effects(expr) then
	--			VisitAst(ast, nil, function(node, _, assigned)
	--				if node.kind == "VariableExpression" and not assigned then
	--					return expr
	--				end
	--
	--				return node
	--			end)
	--		end
	--
	--		return Ast.NopStatement()
	--	end
	--
	--	return node
	--end)

	--[[
	regs[i] = self:allocRegister(false);
                local tmpReg = self:allocRegister(false);
                self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(expression.scope:getVariableName(expression.id))), {tmpReg}, {}, false);
                self:addStatement(self:setRegister(scope, regs[i], Ast.IndexExpression(self:env(scope), self:register(scope, tmpReg))), {regs[i]}, {tmpReg}, true);
                self:freeRegister(tmpReg, false);
	]]

	local function find(t, value)
		for i = 1, #t do
			if t[i] == value then
				return i
			end
		end
	end

	VisitAst(ast, nil, function(node, data)
		if node.kind == "IndexExpression" then
			if data.nodeStack[#data.nodeStack - 2] then
				if data.nodeStack[#data.nodeStack - 2].kind == "Block" then
					local block = data.nodeStack[#data.nodeStack - 2]
					local stmt = find(block.statements, data.nodeStack[#data.nodeStack - 1])

					print(stmt.kind)
				end
			end
		end
	end)
end

--[[
function Ast.IndexExpression(base, index)
	return {
		kind = AstKind.IndexExpression,
		base = base,
		index = index,
		isConstant = false,
	}
end

function Ast.FunctionCallExpression(base, args)
	return {
		kind = AstKind.FunctionCallExpression,
		base = base,
		args = args,
	}
end
]]
