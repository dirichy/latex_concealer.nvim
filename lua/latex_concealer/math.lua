local M = {}
local util = require("latex_concealer.util")
M.config = {
	commands = {
		["\\frac"] = function(arg1, arg2)
			return "(" .. arg1 .. ")/(" .. arg2 .. ")"
		end,
	},
}
function M.conceal(root)
	local query = vim.treesitter.query.parse("latex", "(inline_formula) @match")
	if not root then
		local tree = vim.treesitter.get_parser(0, "latex")
		root = tree:trees()[1]:root()
	end
	for _, node in query:iter_captures(root, 0) do
		M.conceal_math(node)
	end
end

--- i
---@param node TSNode
function M.conceal_math(node)
	local command_name = vim.treesitter.get_node_text(node:field("command")[1], 0)
	if command_name == "\\frac" then
		local arg_nodes = node:field("arg")
		local args = {}
		for _, arg_node in ipairs(arg_nodes) do
			arg_node = arg_node:named_child(0)
			table.insert(args, vim.treesitter.get_node_text(arg_node, 0))
		end
		local text = M.config.commands[command_name](unpack(args))
		local a, b, c, d = node:range()
		util.multichar_conceal(a, b, c, d, text, vim.api.nvim_create_namespace("latex_concealer_symbols"))
	end
end
return M
