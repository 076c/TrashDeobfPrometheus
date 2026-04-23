local VisitAst = require("./../prometheus/visitast")
local Ast = require("./../prometheus/ast")

--[[
local function g(g)
    return J[g + (50061)]
end
]]

--[[
function Ast.FunctionCallExpression(base, args)
	return {
		kind = AstKind.FunctionCallExpression,
		base = base,
		args = args,
	}
end

function Ast.VariableExpression(scope, id)
	scope:addReference(id)
	return {
		kind = AstKind.VariableExpression,
		scope = scope,
		id = id,
		getName = function(self)
			return self.scope.getVariableName(self.id)
		end,
	}
end
]]

return function(ast)
	local constant_table
	local fn_decl

	for i = 1, #ast.body.statements do
		local stmt = ast.body.statements[i]

		if fn_decl ~= nil and constant_table ~= nil then
			break
		end

		if stmt then
			if stmt.kind == "LocalFunctionDeclaration" then
				if fn_decl == nil then
					fn_decl = table.remove(ast.body.statements, i)
				end
			elseif stmt.kind == "LocalVariableDeclaration" then
				if stmt.expressions[1].kind == "TableConstructorExpression" then
					if constant_table == nil then
						constant_table = stmt.expressions[1]
					end
				end
			end
		end
	end

	local dumped_constants = {}

	for _, v in ipairs(constant_table.entries) do
		table.insert(dumped_constants, v.value.value)
	end

	local arith_type = fn_decl.body.statements[1].args[1].index.kind
	local offset = fn_decl.body.statements[1].args[1].index.rhs.value

	VisitAst(ast, function(node)
		if node.kind == "FunctionCallExpression" then
			local base = node.base

			if base.kind ~= "VariableExpression" then
				return node
			end

			if base.scope == fn_decl.scope and base.id == fn_decl.id then
				local left = node.args[1].value
				local right = offset

				local index

				if arith_type == "AddExpression" then
					index = left + right
				elseif arith_type == "SubExpression" then
					index = left - right
				end

				return Ast.StringExpression(dumped_constants[index] or "_NO_CONSTANT_FOUND")
			end
		end

		return node
	end)

	table.remove(ast.body.statements, 1)

	VisitAst(ast, nil, function(node)
		if node.kind == "AssignmentStatement" then
			if #node.lhs <= 1 then
				return node
			end

			local out = {}

			for i = 1, #node.lhs do
				local l = node.lhs[i]
				local r = node.rhs[i] or node.rhs[#node.rhs]

				table.insert(out, Ast.AssignmentStatement({ l }, { r }))
			end

			return table.unpack(out)
		end

		return node
	end)
end
