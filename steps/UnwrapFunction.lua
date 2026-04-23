local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")

local WrapInFunction = Step:extend()
WrapInFunction.Description = "This Step Wraps the Entire Script into a Function"
WrapInFunction.Name = "Wrap in Function"

WrapInFunction.SettingsDescriptor = {
	Iterations = {
		name = "Iterations",
		description = "The Number Of Iterations",
		type = "number",
		default = 1,
		min = 1,
		max = nil,
	},
}

function WrapInFunction:init(_) end

function WrapInFunction:apply(ast)
	for i = 1, self.Iterations, 1 do
		local body = ast.body

		local scope = Scope:new(ast.globalScope)
		body.scope:setParent(scope)

		ast.body = Ast.Block({
			Ast.ReturnStatement({
				Ast.FunctionCallExpression(
					Ast.FunctionLiteralExpression({ Ast.VarargExpression() }, body),
					{ Ast.VarargExpression() }
				),
			}),
		}, scope)
	end
end

return function(ast)
	local function unwrap()
		local changed = false

		if ast.body.kind == "Block" then
			local first_statement = ast.body.statements[1]

			if first_statement and first_statement.kind == "ReturnStatement" then
				local call_expr = first_statement.args[1]

				if
					call_expr
					and call_expr.kind == "FunctionCallExpression"
					and call_expr.base.kind == "FunctionLiteralExpression"
				then
					ast.body = call_expr.base.body
					changed = true
				end
			end
		end

		return changed
	end

	while unwrap() do
	end
end
