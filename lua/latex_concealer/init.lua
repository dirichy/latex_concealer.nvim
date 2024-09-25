local M = {}
local util = require("latex_concealer.util")
local enums = { "enumi", "enumii", "enumiii", "enumiv" }
local function heading_handler(node)
	local node_type = node:type()
	M.cache.counters[node_type] = M.cache.counters[node_type] + 1
	local row, col = node:range()
	local curly_group_node = node:field("text")[1]
	local _, _, end_row, end_col = curly_group_node:range()
	local heading = curly_group_node:named_child(0) and vim.treesitter.get_node_text(curly_group_node:named_child(0), 0)
		or ""
	util.multichar_conceal(
		row,
		col,
		end_row,
		end_col,
		M.cache.counters:formatter(node_type, heading),
		vim.api.nvim_create_namespace("latex_concealer_list")
	)
end
M.cache = {
	counters = setmetatable({
		refresh = function()
			for k, v in pairs(M.cache._counters) do
				if k ~= "item" then
					v.value = 0
				end
			end
		end,
		formatter = function(t, counter_name, heading)
			if counter_name == "item" then
				counter_name = M.cache._counters.item[#M.cache._counters.item]
				if type(counter_name) == "number" then
					return M.config.icon_formatter.unordered[counter_name]
				else
					return {
						string.gsub(
							M.config.icon_formatter.the[counter_name][1],
							"\\([a-zA-Z]*){([a-zA-Z]*)}",
							function(numbering, count)
								return M.config.icon_formatter.numbering[numbering](t[count] or 0)
							end
						),
						M.config.icon_formatter.the[counter_name][2],
					}
				end
			end
			return {
				string.gsub(
					M.config.icon_formatter.the[counter_name][1],
					"\\([a-zA-Z]*){([a-zA-Z]*)}",
					function(numbering, count)
						return M.config.icon_formatter.numbering[numbering](t[count] or 0)
					end
				) .. heading,
				M.config.icon_formatter.the[counter_name][2],
			}
		end,
	}, {
		__metatable = "LaTeX_counter[]",
		__index = function(_, key)
			if key == "item" then
				return M.cache._counters[M.cache._counters.item[#M.cache._counters.item]]
						and M.cache._counters[M.cache._counters.item[#M.cache._counters.item]].value
					or nil
			end
			return M.cache._counters[key] and M.cache._counters[key].value or error("No counter named " .. key)
		end,
		__newindex = function(t, key, value)
			if key == "item" then
				local counter = M.cache._counters.item[#M.cache._counters.item]
				if type(counter) == "string" then
					t[M.cache._counters.item[#M.cache._counters.item]] = value
				end
				return
			end
			M.cache._counters[key].value = value
			if M.cache._counters[key].refresh then
				for _, counter in ipairs(M.cache._counters[key].refresh) do
					t[counter] = 0
				end
			end
		end,
	}),
	_counters = {
		enumi = { value = 0, refresh = { "enumii" } },
		enumii = { value = 0, refresh = { "enumiii" } },
		enumiii = { value = 0, refresh = { "enumiv" } },
		enumiv = { value = 0 },
		chapter = { value = 0, refresh = { "section" } },
		section = { value = 0, refresh = { "subsection" } },
		subsection = { value = 0, refresh = { "subsubsection" } },
		subsubsection = { value = 0 },
		item = {},
	},
}
local function command_expand(cmd, args, node)
	local result = M.config.handler.generic_command[cmd]
	if type(result) == "function" then
		return result(args, node)
	end
	return result
end
M.config = {
	handler = {
		---@type table<string,string[]|string>
		generic_command = {
			function(node)
				local command_name = vim.treesitter.get_node_text(node:field("command")[1], 0)
				---@type string[]|string
				local expanded
				if M.config.handler.generic_command[command_name] then
					local args = {}
					for k, v in ipairs(node:field("arg")) do
						table.insert(args, vim.treesitter.get_node_text(v, 0):sub(2, -2))
					end
					expanded = command_expand(command_name, args, node)
				end
				if expanded then
					local row, col, end_row, end_col = node:range()
					util.multichar_conceal(
						row,
						col,
						end_row,
						end_col,
						expanded,
						vim.api.nvim_create_namespace("latex_concealer_list")
					)
				end
			end,
		},
		chapter = { heading_handler },
		section = { heading_handler },
		subsection = { heading_handler },
		subsubsection = { heading_handler },
		begin = {
			function(node)
				local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], 0)
				if M.config.handler.begin[env_name] then
					return M.config.handler.begin[env_name]()
				end
			end,
			enumerate = function()
				M.cache.enum_depth = M.cache.enum_depth + 1
				M.cache._counters.item[#M.cache._counters.item + 1] = enums[M.cache.enum_depth]
			end,
			itemize = function()
				M.cache.item_depth = M.cache.item_depth + 1
				M.cache._counters.item[#M.cache._counters.item + 1] = M.cache.item_depth
			end,
		},
		["end"] = {
			function(node)
				local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], 0)
				if M.config.handler["end"][env_name] then
					return M.config.handler["end"][env_name]()
				end
			end,
			enumerate = function()
				M.cache.counters.item = 0
				M.cache.enum_depth = M.cache.enum_depth - 1
				M.cache._counters.item[#M.cache._counters.item] = nil
			end,
			itemize = function()
				M.cache.item_depth = M.cache.item_depth - 1
				M.cache._counters.item[#M.cache._counters.item] = nil
			end,
		},
		enum_item = {
			function(node)
				if M.cache.counters.item then
					M.cache.counters.item = M.cache.counters.item + 1
				end
				node = node:child(0)
				local row, col, end_row, end_col = node:range()
				util.multichar_conceal(
					row,
					col,
					end_row,
					end_col,
					M.cache.counters:formatter("item"),
					vim.api.nvim_create_namespace("latex_concealer_list")
				)
			end,
		},
	},
	counters = setmetatable({
		refresh = function()
			for k, v in pairs(M.cache._counters) do
				if k ~= "item" then
					v.value = 0
				end
			end
		end,
		formatter = function(t, counter_name, heading)
			if counter_name == "item" then
				counter_name = M.cache._counters.item[#M.cache._counters.item]
				if type(counter_name) == "number" then
					return M.config.icon_formatter.unordered[counter_name]
				else
					return {
						string.gsub(
							M.config.icon_formatter.the[counter_name][1],
							"\\([a-zA-Z]*){([a-zA-Z]*)}",
							function(numbering, count)
								return M.config.icon_formatter.numbering[numbering](t[count] or 0)
							end
						),
						M.config.icon_formatter.the[counter_name][2],
					}
				end
			end
			return {
				string.gsub(
					M.config.icon_formatter.the[counter_name][1],
					"\\([a-zA-Z]*){([a-zA-Z]*)}",
					function(numbering, count)
						return M.config.icon_formatter.numbering[numbering](t[count] or 0)
					end
				) .. heading,
				M.config.icon_formatter.the[counter_name][2],
			}
		end,
	}, {
		__metatable = "LaTeX_counter[]",
		__index = function(_, key)
			if key == "item" then
				return M.cache._counters[M.cache._counters.item[#M.cache._counters.item]]
						and M.cache._counters[M.cache._counters.item[#M.cache._counters.item]].value
					or nil
			end
			return M.cache._counters[key] and M.cache._counters[key].value or error("No counter named " .. key)
		end,
		__newindex = function(t, key, value)
			if key == "item" then
				local counter = M.cache._counters.item[#M.cache._counters.item]
				if type(counter) == "string" then
					t[M.cache._counters.item[#M.cache._counters.item]] = value
				end
				return
			end
			M.cache._counters[key].value = value
			if M.cache._counters[key].refresh then
				for _, counter in ipairs(M.cache._counters[key].refresh) do
					t[counter] = 0
				end
			end
		end,
	}),
	_counters = {
		enumi = { value = 0, refresh = { "enumii" } },
		enumii = { value = 0, refresh = { "enumiii" } },
		enumiii = { value = 0, refresh = { "enumiv" } },
		enumiv = { value = 0 },
		chapter = { value = 0, refresh = { "section" } },
		section = { value = 0, refresh = { "subsection" } },
		subsection = { value = 0, refresh = { "subsubsection" } },
		subsubsection = { value = 0 },
		item = {},
	},
	conceal_cursor = "nvic",
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
	cursor_refresh_events = { "CursorMovedI", "CursorMoved" },
	icon_formatter = {
		numbering = require("latex_concealer.numbering"),
		heading = {
			chapter = { "\\zhnum{chapter}、", "ErrorMsg" },
			section = { "\\Roman{chapter}.\\roman{section} ", "Constant" },
			subsection = { "\\arabic{chapter}.\\arabic{section}.\\arabic{subsection} ", "DiagnosticHint" },
			subsubsection = {
				"\\arabic{chapter}.\\arabic{section}.\\arabic{subsection}\\alph{subsubsection} ",
				"Special",
			},
		},
		the = {
			chapter = { "\\zhnum{chapter}、", "ErrorMsg" },
			section = { "\\Roman{chapter}.\\roman{section} ", "Constant" },
			subsection = { "\\arabic{chapter}.\\arabic{section}.\\arabic{subsection} ", "DiagnosticHint" },
			subsubsection = {
				"\\arabic{chapter}.\\arabic{section}.\\arabic{subsection}\\alph{subsubsection} ",
				"Special",
			},
			enumi = { "\\zhdig{section}.\\Roman{enumi}.", "ErrorMsg" },
			enumii = { "\\Roman{enumi}.\\Alph{enumii}", "Constant" },
			enumiii = { "\\Roman{enumi}.\\Alph{enumii}(\\zhdig{enumiii})", "DiagnosticHint" },
			enumiv = { "\\fnsymbol{enumiv}", "SpecialKey" },
		},
		unordered = {
			{ "o", "ErrorMsg" },
			{ "-", "Constant" },
			{ "+", "DiagnosticHint" },
			{ "=", "SpecialKey" },
		},
	},
}

function M.deconceal_environment(enum_node)
	local item_node
	local row
	for item in enum_node:iter_children() do
		if item:type() == "enum_item" then
			item_node = item:child(0)
			row = item_node:range()
			vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("latex_concealer_list"), row, row + 1)
		end
	end
end

function M.conceal(root)
	local query_string = ""
	for k, _ in pairs(M.config.handler) do
		query_string = query_string .. " (" .. k .. ") @" .. k
	end
	local query = vim.treesitter.query.parse("latex", query_string)
	if not root then
		local tree = vim.treesitter.get_parser(0, "latex")
		root = tree:trees()[1]:root()
	end
	M.cache.enum_depth = 0
	M.cache.item_depth = 0
	M.cache.counters.refresh()
	for _, node in query:iter_captures(root, 0) do
		local node_type = node:type()
		if M.config.handler[node_type] then
			M.config.handler[node_type][1](node)
		end
	end
end
function M.refresh()
	local timer = vim.uv.new_timer()
	timer:start(
		200,
		0,
		vim.schedule_wrap(function()
			-- vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("latex_concealer_list"), 0, -1)
			M.conceal()
		end)
	)
end
M.cursor_refresh = function()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local extmarks = vim.api.nvim_buf_get_extmarks(
		0,
		vim.api.nvim_create_namespace("latex_concealer_list"),
		{ row, 0 },
		{ row, col },
		{ details = true }
	)
	for _, extmark in ipairs(extmarks) do
		local extstart = extmark[3]
		local extend = extmark[4].end_col
		if extstart <= col and col <= extend then
			util.hide_extmark(extmark)
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
-- 						-- vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("latex_concealer_list"), row, end_row)
-- 						break
-- 					end
-- 				end
-- 				node = node:parent()
-- 			end
-- 		end)
-- 	)
-- end
M.local_refresh = M.refresh
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts)
	if M.config.refresh_events then
		vim.api.nvim_create_autocmd(M.config.refresh_events, {
			buffer = 0,
			callback = M.refresh,
		})
	end
	if M.config.local_refresh_events then
		vim.api.nvim_create_autocmd(M.config.local_refresh_events, {
			buffer = 0,
			callback = M.local_refresh,
		})
	end
	if M.config.cursor_refresh_events then
		vim.api.nvim_create_autocmd(M.config.cursor_refresh_events, {
			buffer = 0,
			callback = M.cursor_refresh,
		})
	end
	require("latex_concealer.handler.symbol").add_handler(M.config.handler)
	M.refresh()
	vim.opt_local.concealcursor = M.config.conceal_cursor
end
return M
