local M = {}
local util = require("latex_concealer.util")
function M.conceal(opts)
	local result = function(buffer, node)
		local command_name = node:field("command")[1]
		local arg_nodes = node:field("arg")
		if #arg_nodes + 1 < #opts then
			return
		end
		local row1, col1 = command_name:range()
		local row1_end, col1_end, row2, col2
		for index, arg_node in ipairs(node:field("arg")) do
			row1_end, col1_end, row2, col2 = arg_node:range()
			util.multichar_conceal(
				buffer,
				row1,
				col1,
				row1_end,
				col1_end + 1,
				opts[index],
				vim.api.nvim_create_namespace("latex_concealer")
			)
			row1 = row2
			col1 = col2
		end
		util.multichar_conceal(
			buffer,
			row1,
			col1 - 1,
			row1,
			col1,
			opts[#opts],
			vim.api.nvim_create_namespace("latex_concealer")
		)
	end
	return result
end
return M
