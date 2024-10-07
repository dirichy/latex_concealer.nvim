local concealer = require("latex_concealer.handler.util").conceal
local filters = require("latex_concealer.filters")
local M = {}
M.cache = {}
local util = require("latex_concealer.extmark")
local counter = require("latex_concealer.counter")
local function heading_handler(buffer, node)
	local node_type = node:type()
	counter.step_counter(buffer, node_type)
	local curly_group_node = node:field("text")[1]
	local heading = curly_group_node:named_child(0)
			and vim.treesitter.get_node_text(curly_group_node:named_child(0), buffer)
		or ""
	local a, b = node:range()
	local _, _, c, d = curly_group_node:range()
	util.multichar_conceal(buffer, { a, b, c, d }, counter.the(buffer, node_type, heading))
end
local function command_expand(buffer, cmd, node)
	local result = M.config.handler.generic_command[cmd]
	if type(result) == "function" then
		return result(buffer, node)
	end
	if result[1] or type(result) == "string" then
		return result
	else
		if result.delim then
			for k, v in pairs(result.delim) do
				concealer.delim[k](buffer, node, v)
			end
		end
		if result.filter then
			for k, v in pairs(result.filter) do
				concealer.filter[k](buffer, node, v)
			end
		end
	end
end

M.config = {
	_handler = {
		subscript = function(buffer, node)
			concealer.script(buffer, node, filters.subscript, "Identifier")
		end,
		superscript = function(buffer, node)
			concealer.script(buffer, node, filters.superscript, "Identifier")
		end,
		generic_command = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer)
			local expanded
			if M.config.handler.generic_command[command_name] then
				expanded = command_expand(buffer, command_name, node)
			end
			if expanded then
				util.multichar_conceal(buffer, { node = node }, expanded)
			end
		end,
		chapter = heading_handler,
		section = heading_handler,
		subsection = heading_handler,
		subsubsection = heading_handler,
		begin = function(buffer, node)
			local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], buffer)
			if M.config.handler.begin[env_name] then
				return M.config.handler.begin[env_name](buffer, node)
			end
		end,
		["end"] = function(buffer, node)
			local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], buffer)
			if M.config.handler["end"][env_name] then
				return M.config.handler["end"][env_name](buffer, node)
			end
		end,
		enum_item = function(buffer, node)
			if counter.cache[buffer].counters.item then
				counter.cache[buffer].counters.item = counter.cache[buffer].counters.item + 1
			end
			node = node:child(0)
			util.multichar_conceal(buffer, { node = node }, counter.the(buffer, "item"))
		end,
	},
	handler = {
		---@type table<string,string[]|string>
		generic_command = require("latex_concealer.handler.generic_command"),
		chapter = {},
		section = {},
		subsection = {},
		subsubsection = {},
		begin = {
			enumerate = function(buffer, node)
				counter.item_depth_change(buffer, true, 1)
			end,
			itemize = function(buffer, node)
				counter.item_depth_change(buffer, false, 1)
			end,
		},
		["end"] = {
			enumerate = function(buffer, node)
				counter.item_depth_change(buffer, true, -1)
			end,
			itemize = function(buffer, node)
				counter.item_depth_change(buffer, false, -1)
			end,
		},
		enum_item = {},
	},
	conceal_cursor = "nvic",
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
	cursor_refresh_events = { "CursorMovedI", "CursorMoved" },
}

function M.conceal(buffer, root)
	local query_string = ""
	for k, _ in pairs(M.config._handler) do
		query_string = query_string .. " (" .. k .. ") @" .. k
	end
	local query = vim.treesitter.query.parse("latex", query_string)
	if not root then
		local tree = vim.treesitter.get_parser(buffer, "latex")
		root = tree:trees()[1]:root()
	end
	counter.reset_all(buffer)
	for _, node in query:iter_captures(root, buffer) do
		local node_type = node:type()
		if M.config._handler[node_type] then
			M.config._handler[node_type](buffer, node)
		end
	end
end

function M.refresh(buffer)
	local timer = vim.uv.new_timer()
	timer:start(
		200,
		0,
		vim.schedule_wrap(function()
			vim.api.nvim_buf_clear_namespace(buffer, vim.api.nvim_create_namespace("latex_concealer"), 0, -1)
			counter.reset_all(buffer)
			util.delete_all(buffer)
			M.conceal(buffer)
		end)
	)
end

M.cursor_refresh = function(buffer)
	util.restore_and_gc(buffer)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local extmarks = vim.api.nvim_buf_get_extmarks(
		buffer,
		vim.api.nvim_create_namespace("latex_concealer"),
		{ row, 0 },
		{ row, col },
		{ details = true }
	)
	for _, extmark in ipairs(extmarks) do
		local extstart = extmark[3]
		local extend = extmark[4].end_col
		if extstart <= col and col <= extend then
			util.hide_extmark(extmark, buffer)
		end
	end
end

M.local_refresh = M.refresh
function M.setup_buf(buffer)
	if M.cache[buffer] then
		return
	end
	M.cache[buffer] = true
	buffer = buffer and (type(buffer) == "number" and buffer or buffer.buf) or vim.api.nvim_get_current_buf()
	if M.config.refresh_events then
		vim.api.nvim_create_autocmd(M.config.refresh_events, {
			buffer = buffer,
			callback = function()
				M.refresh(buffer)
			end,
		})
	end
	if M.config.local_refresh_events then
		vim.api.nvim_create_autocmd(M.config.local_refresh_events, {
			buffer = buffer,
			callback = function()
				M.local_refresh(buffer)
			end,
		})
	end
	if M.config.cursor_refresh_events then
		vim.api.nvim_create_autocmd(M.config.cursor_refresh_events, {
			buffer = buffer,
			callback = function()
				M.cursor_refresh(buffer)
			end,
		})
	end
	counter.setup_buf(buffer)
	util.setup_buf(buffer)
	M.refresh(buffer)
	vim.api.nvim_set_option_value("concealcursor", M.config.conceal_cursor, { scope = "local" })
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts)
	counter.setup(M.config.counter)
	M.setup_buf(0)
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.tex",
		callback = M.setup_buf,
	})
end

return M
