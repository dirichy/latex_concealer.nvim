local M = {}
M.MATH_NODES = {
	displayed_equation = true,
	inline_formula = true,
	math_environment = true,
}

M.TEXT_NODES = {
	text_mode = true,
	label_definition = true,
	label_reference = true,
}
M.ENV_NODES = {
	generic_environment = true,
	math_environment = true,
	comment_environment = true,
	verbatim_environment = true,
	listing_environment = true,
	minted_environment = true,
	pycode_environment = true,
	sagesilent_environment = true,
	sageblock_environment = true,
}
M.CMD_NODES = {
	generic_command = true,
}
--- get node under cursor
--- @return TSNode|nil
M.get_node_at_cursor = require("nvim-treesitter.ts_utils").get_node_at_cursor

M.node_parent = function(node, bufer)
	return node:parent()
end
-- M.node_parent = function(node, bufer)
-- 	if not node then
-- 		return nil
-- 	end
-- 	if node:parent() then
-- 		return node:parent()
-- 	end
-- 	if vim.bo.filetype == "tex" or vim.bo.filetype == "latex_snip" then
-- 		return nil
-- 	end
-- 	if node:start() == 0 then
-- 		return nil
-- 	end
-- 	return vim.treesitter.get_node(bufer)
-- end
-- 	local pos = vim.api.nvim_win_get_cursor(0)
-- 	-- Subtract one to account for 1-based row indexing in nvim_win_get_cursor
-- 	local row, col = pos[1] - 1, pos[2]
-- 	local parser = vim.treesitter.get_parser(0, "latex_snip")
-- 	if not parser then
-- 		return
-- 	end
-- 	local root_tree = parser:parse({ row, col, row, col })[1]
-- 	local root = root_tree and root_tree:root()
-- 	if not root then
-- 		return
-- 	end
-- 	return root:named_descendant_for_range(row, col, row, col)
-- end
return M
