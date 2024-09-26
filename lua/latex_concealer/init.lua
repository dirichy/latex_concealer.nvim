local M = {}
M.cache = {}
local util = require("latex_concealer.util")
local counter = require("latex_concealer.counter")
local function heading_handler(buffer, node)
	local node_type = node:type()
	counter.step_counter(buffer, node_type)
	local row, col = node:range()
	local curly_group_node = node:field("text")[1]
	local _, _, end_row, end_col = curly_group_node:range()
	local heading = curly_group_node:named_child(0)
			and vim.treesitter.get_node_text(curly_group_node:named_child(0), buffer)
		or ""
	util.multichar_conceal(
		buffer,
		row,
		col,
		end_row,
		end_col,
		counter.the(buffer, node_type, heading),
		vim.api.nvim_create_namespace("latex_concealer")
	)
end
local function command_expand(buffer, cmd, node)
	local result = M.config.handler.generic_command[cmd]
	if type(result) == "function" then
		return result(buffer, node)
	end
	return result
end

M.config = {
	_handler = {
		generic_command = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer)
			local expanded
			if M.config.handler.generic_command[command_name] then
				expanded = command_expand(buffer, command_name, node)
				-- else
				-- 	util.delete_extmark(buffer, node)
				-- 	return
			end
			if expanded then
				local row, col, end_row, end_col = node:range()
				util.multichar_conceal(
					buffer,
					row,
					col,
					end_row,
					end_col,
					expanded,
					vim.api.nvim_create_namespace("latex_concealer")
				)
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
			local row, col, end_row, end_col = node:range()
			util.multichar_conceal(
				buffer,
				row,
				col,
				end_row,
				end_col,
				counter.the(buffer, "item") or ("error: " .. tostring(row) .. tostring(col)),
				vim.api.nvim_create_namespace("latex_concealer")
			)
		end,
	},
	handler = {
		---@type table<string,string[]|string>
		generic_command = {},
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

-- function M.deconceal_environment(enum_node, buffer)
-- 	local item_node
-- 	local row
-- 	for item in enum_node:iter_children() do
-- 		if item:type() == "enum_item" then
-- 			item_node = item:child(0)
-- 			row = item_node:range()
-- 			vim.api.nvim_buf_clear_namespace(
-- 				buffer,
-- 				vim.api.nvim_create_namespace("latex_concealer"),
-- 				row,
-- 				row + 1
-- 			)
-- 		end
-- 	end
-- end

function M.conceal(buffer, root)
	local query_string = ""
	for k, _ in pairs(M.config.handler) do
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
		if M.config.handler[node_type] then
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
	-- col=col-1
	-- local node=vim.treesitter.get_node({buffer=buffer,pos={row,col}})
	for _, extmark in ipairs(extmarks) do
		local extstart = extmark[3]
		local extend = extmark[4].end_col
		if extstart <= col and col <= extend then
			util.hide_extmark(extmark, buffer)
		end
	end
end
-- function M.local_refresh()
-- 	local timer = vim.uv.new_timer()
-- 	timer:start(
-- 		200,
-- 		0,
-- 		vim.schedule_wrap(function()
-- 			local node = require("nvim-treesitter.ts_utils").get_node_at_cursor()
-- 			while node do
-- 				if node:type() == "generic_environment" then
-- 					local env_name =
-- 						vim.treesitter.get_node_text(node:field("begin")[1]:field("name")[1]:field("text")[1], 0)
-- 					if env_name == "itemize" or env_name == "enumerate" then
-- 						M.deconceal_environment(node)
-- 						M.conceal_environment(node, env_name == "enumerate")
-- 						-- vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("latex_concealer"), row, end_row)
-- 						break
-- 					end
-- 				end
-- 				node = node:parent()
-- 			end
-- 		end)
-- 	)
-- end
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
	M.config.handler.generic_command = require("latex_concealer.handler.symbol")
	M.setup_buf(0)
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.tex",
		callback = M.setup_buf,
	})
end

return M
