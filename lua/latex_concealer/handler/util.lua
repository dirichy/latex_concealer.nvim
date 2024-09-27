local M = {}
local util = require("latex_concealer.util")
function M.conceal_commands(opts)
	opts.map = opts.map or {}
	opts.delim = opts.delim or {}
	local result = function(buffer, node)
		local command_name = node:field("command")[1]
		local arg_nodes = node:field("arg")
		if #arg_nodes + 1 < #opts.delim then
			return
		end
		local row1, col1 = command_name:range()
		local row1_end, col1_end, row2, col2
		for index, arg_node in ipairs(arg_nodes) do
			row1_end, col1_end, row2, col2 = arg_node:range()
			util.multichar_conceal(
				buffer,
				row1,
				col1,
				row1_end,
				col1_end + 1,
				opts.delim[index] or "",
				vim.api.nvim_create_namespace("latex_concealer")
			)
			if opts.map[index] then
				local text = vim.treesitter.get_node_text(arg_node, buffer):sub(2, -2)
				util.multichar_conceal(buffer, row1_end, col1_end + 1, row2, col2 - 1, {
					string.gsub(text, ".", function(str)
						return opts.map[index][1][str] or str
					end),
					opts.map[index][2],
				}, vim.api.nvim_create_namespace("latex_concealer"))
			end
			row1 = row2
			col1 = col2 - 1
		end
		if opts.delim[#opts.delim] then
			util.multichar_conceal(
				buffer,
				row1,
				col1,
				row1,
				col1 + 1,
				opts.delim[#opts.delim] or "",
				vim.api.nvim_create_namespace("latex_concealer")
			)
		end
	end
	return result
end
return M
