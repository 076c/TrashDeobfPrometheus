local Ast = require("./../prometheus/ast")
local VisitAst = require("./../prometheus/visitast")

--[[
function Ast.FunctionLiteralExpression(args, body)
	return {
		kind = AstKind.FunctionLiteralExpression,
		args = args,
		body = body,
	}
end
]]

-- return function(ast)
-- 	local call_fn = ast.body.statements[1].args[1]
-- 	local fn_literal = call_fn.base

-- 	for i, arg in ipairs(fn_literal.args) do
-- 		if not (arg.kind == "TableConstructorExpression" and arg.entries[1].value.kind == "VarargExpression") then
-- 			local ident = call_fn.args[i]

-- 			local stmt = Ast.AssignmentStatement({ arg }, { ident })

-- 			table.insert(fn_literal.body.statements, 1, stmt)
-- 		end
-- 	end

-- 	ast.body.statements = fn_literal.body.statements
-- end

return function(ast)
	local call_fn = ast.body.statements[1].args[1]
	local fn_literal = call_fn.base

	local fn_args = fn_literal.args
	local call_args = call_fn.args

	local var_to_val_map = {}

	for i = 1, math.min(#fn_args, #call_args) do
		local fn_arg = fn_args[i]
		local call_arg = call_args[i]

		if
			fn_arg
			and call_arg
			and not (
				fn_arg.kind == "TableConstructorExpression"
				and fn_arg.entries
				and fn_arg.entries[1]
				and fn_arg.entries[1].value
				and fn_arg.entries[1].value.kind == "VarargExpression"
			)
		then
			local stmt = Ast.AssignmentStatement({ fn_arg }, { call_arg })

			var_to_val_map[{ fn_arg.id, fn_arg.scope }] = call_arg

			table.insert(fn_literal.body.statements, 1, stmt)
		end
	end

	ast.body.statements = fn_literal.body.statements

	VisitAst(ast, nil, function(node)
		if node.kind == "VariableExpression" then
			local included

			for i, v in pairs(var_to_val_map) do
				if i[1] == node.id and i[2] == node.scope then
					included = v
				end
			end

			if included and included.kind == "VariableExpression" then
				return included
			end
		end
	end)
end
