local M = {}
local concealer = require("latex_concealer")
M.config = {
	extmark = {
		-- virt_text = { { list_icon_formatter(depth, index), "@keyword" } },
		virt_text_pos = "inline",
		conceal = "",
		invalidate = true,
		-- end_row = end_row,
		-- end_col = end_col,
	},
}
function M.clear(node)
	local start_row, _, end_row = node and node:range() or 0, 0, -1
	vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("concealer_latex"), start_row, end_row)
end
function M.multichar_conceal(start_row, start_col, end_row, end_col, text, namespace_id, user_opts)
	local opts = table.copy(M.config.extmark)
	opts = vim.tbl_deep_extend("force", opts, user_opts or {})
	opts.virt_text = type(text) == "string" and { { text, "Conceal" } }
		or type(text[1] == "string") and { text }
		or text
	opts.end_row = end_row
	opts.end_col = end_col
	local extmarks = vim.api.nvim_buf_get_extmarks(
		0,
		namespace_id,
		{ start_row, start_col },
		{ end_row, end_col },
		{ details = true }
	)
	for _, extmark in ipairs(extmarks) do
		if extmark[2] == start_row and extmark[3] == start_col then
			opts.id = extmark[1]
		end
	end
	vim.api.nvim_buf_set_extmark(0, namespace_id, start_row, start_col, opts)
end
function M.restore(extmark)
	concealer.cache.extmark[extmark[1]] = extmark
	vim.api.nvim_buf_set_extmark(0, vim.api.nvim_)
end
return M