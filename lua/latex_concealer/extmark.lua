local counter = require("latex_concealer.counter")
local M = {}
---@type table<number,table>
M.cache = {}
M.config = {
	highlight = {
		rainbow = { "Special", "Operator", "ErrorMsg", "DiagnosticHint" },
		constant = "Constant",
		symbol = "Special",
		reference = "Special",
		_delim = "Special",
		delim = "_delim",
		operator = "Operator",
		hugeoperator = "Operator",
		chapter = "ErrorMsg",
		section = "Constant",
		subsection = "DiagnosticHint",
		subsubsection = "Special",
		enumerate = {
			enumi = "ErrorMsg",
			enumii = "Constant",
			enumiii = "DiagnosticHint",
			enumiv = "Special",
			error = "ErrorMsg",
		},
		itemize = { "ErrorMsg", "Constant", "DiagnosticHint", "Special", "ErrorMsg" },
		greek = "DiagnosticHint",
		operatorname = "Constant",
		arrow = "Function",
		relationship = "Identifier",
		fraction = "Constant",
		footnotemark = "Special",
		error = "ErrorMsg",
		script = "Identifier",
		default = "Conceal",
	},
	ns_id = vim.api.nvim_create_namespace("latex_concealer"),
	extmark = {
		virt_text_pos = "inline",
		invalidate = true,
		undo_restore = false,
		conceal = "",
	},
	rainbow = true,
}
function M.clear(node, buffer)
	local start_row, _, end_row = node and node:range() or 0, 0, -1
	vim.api.nvim_buf_clear_namespace(buffer, vim.api.nvim_create_namespace("concealer_latex"), start_row, end_row)
end

function M.multichar_conceal(buffer, range, text, user_opts)
	local start_row, start_col, end_row, end_col
	user_opts = user_opts or {}
	local ns_id = user_opts.ns_id or M.config.ns_id
	user_opts.ns_id = nil
	if range[1] then
		start_row, start_col, end_row, end_col = unpack(range)
	else
		start_row, start_col, end_row, end_col = range.node:range()
		if range.offset then
			start_row = start_row + range.offset[1]
			start_col = start_col + range.offset[2]
			end_row = end_row + range.offset[3]
			end_col = end_col + range.offset[4]
		end
	end
	local opts = vim.fn.deepcopy(M.config.extmark)
	opts = vim.tbl_deep_extend("force", opts, user_opts)
	opts.virt_text = type(text) == "string" and { { text, "Conceal" } }
		or type(text[1]) == "string" and { text }
		or text
		or { { "", "" } }
	opts.end_row = end_row
	opts.end_col = end_col
	for _, value in ipairs(opts.virt_text) do
		if value[2] == "_delim" then
			value[2] = M.config.rainbow and M.config.highlight.rainbow[counter.get(buffer, "_bracket")] or "Special"
		end
	end
	local extmark = vim.api.nvim_buf_set_extmark(buffer, ns_id, start_row, start_col, opts)
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1
	if
		(cursor_row > start_row or cursor_row == start_row and cursor_col > start_col - 1)
		and (cursor_row < end_row or cursor_row == end_row and cursor_col < end_col + 1)
	then
		M.hide_extmark(extmark, buffer)
	end
end

--- use in restore_and_gc to restore a extmark when the cursor is on it.
---@param extmark number|vim.api.keyset.get_extmark_item
---@param buffer number
function M.hide_extmark(extmark, buffer)
	if type(extmark) == "number" then
		local actual_extmark =
			vim.api.nvim_buf_get_extmark_by_id(buffer, M.config.ns_id, extmark, { details = true, hl_name = true })
		table.insert(actual_extmark, 1, extmark)
		extmark = actual_extmark
	end
	if extmark[4].conceal then
		M.cache[buffer].extmark[extmark[1]] = vim.fn.copy(extmark[4].virt_text)
		local opts = extmark[4]
		if opts.invalid then
			return
		end
		opts.virt_text = nil
		opts.conceal = nil
		opts.id = extmark[1]
		opts.ns_id = nil
		vim.api.nvim_buf_set_extmark(buffer, M.config.ns_id, extmark[2], extmark[3], opts)
	end
end

function M.delete_all(buffer)
	vim.api.nvim_buf_clear_namespace(buffer, M.config.ns_id, 0, -1)
	M.cache[buffer].extmark = {}
end
---remove extmarks when the cursor is on it, and add it back when cursor leave.
---@param buffer number
function M.restore_and_gc(buffer)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local extmarks = vim.api.nvim_buf_get_extmarks(
		buffer,
		vim.api.nvim_create_namespace("latex_concealer"),
		{ row, 0 },
		{ row, col },
		{ details = true }
	)
	for _, mark in ipairs(extmarks) do
		local extstart = mark[3]
		local extend = mark[4].end_col
		if extstart <= col and col <= extend then
			M.hide_extmark(mark, buffer)
		end
	end
	for id, extmark in pairs(M.cache[buffer].extmark) do
		local hided_extmark = vim.api.nvim_buf_get_extmark_by_id(buffer, M.config.ns_id, id, { details = true })
		if not hided_extmark or not hided_extmark[3] then
			M.cache[buffer].extmark[id] = nil
		else
			if hided_extmark[1] ~= row or hided_extmark[2] > col + 1 or hided_extmark[3].end_col < col then
				M.multichar_conceal(
					buffer,
					{ hided_extmark[1], hided_extmark[2], hided_extmark[3].end_row, hided_extmark[3].end_col },
					extmark[1] or "",
					{ id = id }
				)
				M.cache[buffer].extmark[id] = nil
			end
		end
	end
end
function M.setup_buf(buffer)
	M.cache[buffer] = { extmark = {} }
end
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts)
end
return M
