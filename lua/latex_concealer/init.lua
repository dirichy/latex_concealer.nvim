local concealer = require("latex_concealer.handler.util").conceal
local filters = require("latex_concealer.filters")
local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local M = {}
M.cache = {}
local counter = require("latex_concealer.counter")
local function heading_handler(buffer, node)
	local node_type = node:type()
	counter.step_counter(buffer, node_type)
	local curly_group_node = node:field("text")[1]
	local heading = curly_group_node:named_child(0)
			and vim.treesitter.get_node_text(curly_group_node:named_child(0), buffer)
		or ""
	local a, b = node:range()
	local c, d, e, f = curly_group_node:range()
	d = d + 1
	extmark.multichar_conceal(buffer, { a, b, c, d }, { counter.the(buffer, node_type), highlight[node_type] })
	extmark.multichar_conceal(buffer, { e, f - 1, e, f }, "")
end
local function command_expand(buffer, cmd, node)
	local result = M.config.handler.generic_command[cmd]
	if type(result) == "function" then
		result = result(buffer, node)
		if not result then
			return
		end
	end
	if result[1] or type(result) == "string" then
		return result
	else
		if result.font then
			return concealer.font(buffer, node, result.font[1], result.font[2], result.font.opts)
		end
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
		math_delimiter = function(buffer, node)
			local left_node = node:field("left_command")[1]
			local right_node = node:field("right_command")[1]
			extmark.multichar_conceal(buffer, { node = left_node }, "")
			extmark.multichar_conceal(buffer, { node = right_node }, "")
		end,
		label_definition = function(buffer, node)
			local row1, col1, row2, col2 = node:range()
			extmark.multichar_conceal(buffer, { row1, col1, row1, col1 + 7 }, { "🔖(", highlight.reference })
			extmark.multichar_conceal(buffer, { row2, col2 - 1, row2, col2 }, { ")", highlight.reference })
		end,
		label_reference = function(buffer, node)
			local row1, col1, row2, col2 = node:range()
			local text = vim.treesitter.get_node_text(node, buffer)
			local offset = string.find(text, "{")
			extmark.multichar_conceal(buffer, { row1, col1, row1, col1 + offset }, { "🔗(", highlight.reference })
			extmark.multichar_conceal(buffer, { row2, col2 - 1, row2, col2 }, { ")", highlight.reference })
		end,
		subscript = function(buffer, node)
			concealer.script(buffer, node, filters.subscript, highlight.script)
		end,
		superscript = function(buffer, node)
			concealer.script(buffer, node, filters.superscript, highlight.script)
		end,
		generic_command = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer)
			local expanded
			if M.config.handler.generic_command[command_name] then
				expanded = command_expand(buffer, command_name, node)
			end
			if expanded then
				extmark.multichar_conceal(buffer, { node = node }, expanded)
			end
		end,
		command_name = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node, buffer)
			local expanded = M.config.handler.command_name[command_name]
			if expanded then
				extmark.multichar_conceal(buffer, { node = node }, expanded)
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
			local virt_text, cur_counter = counter.the(buffer, "item")
			local hili
			if virt_text then
				if type(cur_counter) == "number" then
					hili = highlight.itemize[cur_counter]
				elseif type(cur_counter) == "string" then
					hili = highlight.enumerate[cur_counter]
				else
					return
				end
				extmark.multichar_conceal(buffer, { node = node }, { virt_text, hili })
			end
		end,
	},
	handler = {
		---@type table<string,string[]|string>
		generic_command = require("latex_concealer.handler.generic_command"),
		command_name = require("latex_concealer.handler.command_name"),
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
	extmark = {},
	conceal_cursor = "nvic",
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
	cursor_refresh_events = { "CursorMovedI", "CursorMoved" },
}

local query_string = ""
for k, _ in pairs(M.config._handler) do
	query_string = query_string .. " (" .. k .. ") @" .. k
end
local query = vim.treesitter.query.parse("latex", query_string)
function M.conceal(buffer, root)
	if not root then
		local tree = vim.treesitter.get_parser(buffer, "latex")
		root = tree:trees()[1]:root()
	end
	counter.reset_all(buffer)
	for _, node in query:iter_captures(root, buffer) do
		local _, _, c, d = vim.treesitter.get_node_range(node)
		local hook = M.cache[buffer].hook
		while c > hook[#hook].pos[1] or c == hook[#hook].pos[1] and d > hook[#hook].pos[2] do
			table.remove(hook).callback(buffer)
		end
		local node_type = node:type()
		if M.config._handler[node_type] then
			M.config._handler[node_type](buffer, node)
		end
	end
end

function M.refresh(buffer)
	vim.schedule(function()
		vim.api.nvim_buf_clear_namespace(buffer, vim.api.nvim_create_namespace("latex_concealer"), 0, -1)
		counter.reset_all(buffer)
		extmark.delete_all(buffer)
		M.conceal(buffer)
	end)
end

M.cursor_refresh = function(buffer)
	extmark.restore_and_gc(buffer)
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
			extmark.hide_extmark(mark, buffer)
		end
	end
end

M.local_refresh = M.refresh
function M.setup_buf(buffer)
	if M.cache[buffer] then
		return
	end
	M.cache[buffer] = { hook = {} }
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
	extmark.setup_buf(buffer)
	M.refresh(buffer)
	if M.config.conceal_cursor then
		vim.api.nvim_set_option_value("concealcursor", M.config.conceal_cursor, { scope = "local" })
	end

	vim.api.nvim_set_option_value("conceallevel", 2, { scope = "local" })
end

function M.setup(opts)
	if vim.g.latex_concealer_disabled then
		return
	end
	M.config = vim.tbl_deep_extend("force", M.config, opts)
	counter.setup(M.config.counter)
	extmark.setup(M.config.extmark)
	M.setup_buf(vim.api.nvim_get_current_buf(0))
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.tex",
		callback = M.setup_buf,
	})
end

return M
