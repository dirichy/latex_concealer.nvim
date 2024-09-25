local M = {}
M.cache = { extmark = {} }
M.config = {
	extmark = {
		virt_text_pos = "inline",
		conceal = "",
		invalidate = true,
	},
}
function M.clear(node, buffer)
	local start_row, _, end_row = node and node:range() or 0, 0, -1
	vim.api.nvim_buf_clear_namespace(buffer, vim.api.nvim_create_namespace("concealer_latex"), start_row, end_row)
end
function M.multichar_conceal(start_row, start_col, end_row, end_col, text, namespace_id, user_opts, buffer)
	local opts = vim.fn.deepcopy(M.config.extmark)
	opts = vim.tbl_deep_extend("force", opts, user_opts or {})
	opts.virt_text = type(text) == "string" and { { text, "Conceal" } }
		or type(text[1] == "string") and { text }
		or text
	opts.end_row = end_row
	opts.end_col = end_col
	local extmarks = vim.api.nvim_buf_get_extmarks(
		buffer,
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
	vim.api.nvim_buf_set_extmark(
		buffer,
		namespace_id or vim.api.nvim_create_namespace("latex_concealer_list"),
		start_row,
		start_col,
		opts
	)
end

function M.hide_extmark(extmark, buffer)
	if extmark[4].virt_text then
		M.cache.extmark[extmark[1]] = vim.fn.copy(extmark[4].virt_text)
		local opts = extmark[4]
		opts.virt_text = nil
		opts.conceal = nil
		opts.id = extmark[1]
		opts.ns_id = nil
		vim.api.nvim_buf_set_extmark(
			buffer,
			vim.api.nvim_create_namespace("latex_concealer_list"),
			extmark[2],
			extmark[3],
			opts
		)
	end
end

function M.restore_and_gc(buffer)
	local row, col = unpack(vim.api.nvim_win_get_cursor(buffer))
	row = row - 1
	for id, extmark in pairs(M.cache.extmark) do
		local hided_extmark = vim.api.nvim_buf_get_extmark_by_id(
			buffer,
			vim.api.nvim_create_namespace("latex_concealer_list"),
			id,
			{ details = true }
		)
		if not hided_extmark then
			M.cache.extmark[id] = nil
		else
			vim.print(hided_extmark)
			if hided_extmark[1] ~= row or hided_extmark[2] > col + 1 or hided_extmark[3].end_col < col then
				M.multichar_conceal(
					hided_extmark[1],
					hided_extmark[2],
					hided_extmark[3].end_row,
					hided_extmark[3].end_col,
					extmark[1],
					vim.api.nvim_create_namespace("latex_concealer_list"),
					{ id = id }
				)
				M.cache.extmark[id] = nil
			end
		end
	end
end
return M
