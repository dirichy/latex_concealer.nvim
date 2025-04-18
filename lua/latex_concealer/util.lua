local M = {}
---@type table<number,table>
M.cache = {}
M.config = {
	extmark = {
		virt_text_pos = "inline",
		invalidate = true,
		undo_restore = false,
		conceal = "",
	},
	["if"] = {
		mmode = false,
		_handler = true,
	},
}
function M.clear(node, buffer)
	local start_row, _, end_row = node and node:range() or 0, 0, -1
	vim.api.nvim_buf_clear_namespace(buffer, vim.api.nvim_create_namespace("concealer_latex"), start_row, end_row)
end

function M.multichar_conceal(buffer, start_row, start_col, end_row, end_col, text, namespace_id, user_opts)
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
			M.cache[buffer].extmark[extmark[1]] = nil
		end
	end
	vim.api.nvim_buf_set_extmark(
		buffer,
		namespace_id or vim.api.nvim_create_namespace("latex_concealer"),
		start_row,
		start_col,
		opts
	)
end

function M.hide_extmark(extmark, buffer)
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
		vim.api.nvim_buf_set_extmark(
			buffer,
			vim.api.nvim_create_namespace("latex_concealer"),
			extmark[2],
			extmark[3],
			opts
		)
	end
end
function M.delete_all(buffer)
	M.cache[buffer].extmark = {}
end
function M.restore_and_gc(buffer)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	for id, extmark in pairs(M.cache[buffer].extmark) do
		local hided_extmark = vim.api.nvim_buf_get_extmark_by_id(
			buffer,
			vim.api.nvim_create_namespace("latex_concealer"),
			id,
			{ details = true }
		)
		if not hided_extmark or not hided_extmark[3] then
			M.cache[buffer].extmark[id] = nil
		else
			if hided_extmark[1] ~= row or hided_extmark[2] > col + 1 or hided_extmark[3].end_col < col then
				M.multichar_conceal(
					buffer,
					hided_extmark[1],
					hided_extmark[2],
					hided_extmark[3].end_row,
					hided_extmark[3].end_col,
					extmark[1] or "",
					vim.api.nvim_create_namespace("latex_concealer"),
					{ id = id }
				)
				M.cache[buffer].extmark[id] = nil
			end
		end
	end
end

--- init for a buffer
---@param buffer number
function M.setup_buf(buffer)
	if M.cache[buffer] then
		return
	end
	M.cache[buffer] = { hook = {} }
	M.cache[buffer]["if"] = vim.deepcopy(M.config["if"])
end

--- add hook to a position
---@param buffer number
---@param position number[]|TSNode
---@param callback function(number)->boolean
---@return boolean
function M.hook(buffer, position, callback)
	local pos
	if type(position) ~= "table" then
		local _, _, c, d = vim.treesitter.get_node_range(position)
		pos = { c, d }
	else
		pos = position
	end
	local flag
	for index, value in ipairs(M.cache[buffer].hook) do
		if pos[1] > value.pos[1] or pos[1] == value.pos[1] and pos[2] > value.pos[2] then
			table.insert(M.cache[buffer].hook, index, { pos = pos, callback = callback })
			flag = true
			break
		end
	end
	if not flag then
		table.insert(M.cache[buffer].hook, { pos = pos, callback = callback })
	end
	return true
end

--- set a if variable for a buffer
---@param buffer number
---@param name string
---@param value boolean
function M.set_if(buffer, name, value)
	M.cache[buffer]["if"][name] = value
end

--- get if variable
---@param buffer number
---@param name string
---@return boolean
function M.get_if(buffer, name)
	return M.cache[buffer]["if"][name]
end

--- toggle if before a position
---@param buffer number
---@param name string
---@param position number[]|TSNode
function M.toggle_if_rangal(buffer, name, position)
	M.cache[buffer]["if"][name] = not M.cache[buffer]["if"][name]
	M.hook(buffer, position, function(buf)
		M.cache[buf]["if"][name] = not M.cache[buf]["if"][name]
	end)
end

--- reinit cache for a buffer
---@param buffer number
function M.reset_all(buffer)
	M.cache[buffer] = { hook = {} }
	M.cache[buffer]["if"] = vim.deepcopy(M.config["if"])
end

function M.stack_not(buffer, node)
	if node then
		M.cache[buffer]["not"] = node
	end
	return M.cache[buffer]["not"]
end

function M.delete_stack(buffer)
	M.cache[buffer]["not"] = nil
end

return M
