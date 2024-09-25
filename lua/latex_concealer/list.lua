local M = {}
local util = require("latex_concealer.util")
M.config = {
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
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

-- local function list_icon_formatter(depth, index, heading, counters)
-- 	if index == -1 then
-- 		return M.config.icon_formatter.unordered[depth]
-- 	end
-- 	if type(depth) == "string" then
-- 		return {
-- 			string.gsub(
-- 				M.config.icon_formatter.heading[depth][1],
-- 				"\\([a-zA-Z]*){([a-zA-Z]*)}",
-- 				function(numbering, counter)
-- 					return M.config.icon_formatter.numbering[numbering](counters[counter] or 0)
-- 				end
-- 			) .. heading,
-- 			M.config.icon_formatter.heading[depth][2],
-- 		}
-- 	end
-- 	return {
-- 		string.gsub(M.config.icon_formatter.ordered[depth][1], "\\([a-zA-Z]*){[a-zA-Z]*}", function(str)
-- 			return M.config.icon_formatter.numbering[str](index)
-- 		end),
-- 		M.config.icon_formatter.ordered[depth][2],
-- 	}
-- end

--- i
---@param node TSNode
-- local function conceal_enum_node(node, index, depth)
-- 	if node:type() ~= "enum_item" then
-- 		error("not enum_item node")
-- 	end
-- 	node = node:child(0)
-- 	local row, col, end_row, end_col = node:range()
-- 	util.multichar_conceal(
-- 		row,
-- 		col,
-- 		end_row,
-- 		end_col,
-- 		list_icon_formatter(depth, index),
-- 		vim.api.nvim_create_namespace("latex_concealer")
-- 	)
-- end

--- i
---@param enum_node TSNode
-- function M.conceal_environment(enum_node, ordered)
-- 	local enum_env = ordered and "enumerate" or "itemize"
-- 	local node = enum_node:parent()
-- 	local depth = 1
-- 	while node do
-- 		if
-- 			node:type() == "generic_environment"
-- 			and vim.treesitter.get_node_text(node:field("begin")[1]:field("name")[1]:field("text")[1], 0)
-- 				== enum_env
-- 		then
-- 			depth = depth + 1
-- 		end
-- 		node = node:parent()
-- 	end
-- 	local index = ordered and 1 or -1
-- 	for item in enum_node:iter_children() do
-- 		if item:type() == "enum_item" then
-- 			conceal_enum_node(item, index, depth)
-- 			if ordered then
-- 				index = index + 1
-- 			end
-- 		end
-- 	end
-- end

function M.deconceal_environment(enum_node)
	local item_node
	local row
	for item in enum_node:iter_children() do
		if item:type() == "enum_item" then
			item_node = item:child(0)
			row = item_node:range()
			vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("latex_concealer"), row, row + 1)
		end
	end
end

function M.conceal(root)
	local query = vim.treesitter.query.parse(
		"latex",
		"(begin) @begin (end) @end (enum_item) @item (chapter) @chapter (section) @section (subsection) @subsection (subsubsection) @subsubsection"
	)
	if not root then
		local tree = vim.treesitter.get_parser(0, "latex")
		root = tree:trees()[1]:root()
	end
	local enum_depth = 0
	local item_depth = 0
	local _counters = {
		enumi = { value = 0, refresh = { "enumii" } },
		enumii = { value = 0, refresh = { "enumiii" } },
		enumiii = { value = 0, refresh = { "enumiv" } },
		enumiv = { value = 0 },
		chapter = { value = 0, refresh = { "section" } },
		section = { value = 0, refresh = { "subsection" } },
		subsection = { value = 0, refresh = { "subsubsection" } },
		subsubsection = { value = 0 },
		item = {},
	}
	local counter_mate = {
		__metatable = "LaTeX_counter[]",
		__index = function(_, key)
			if key == "item" then
				return _counters[_counters.item[#_counters.item]] and _counters[_counters.item[#_counters.item]].value
					or nil
			end
			return _counters[key] and _counters[key].value or error("No counter named " .. key)
		end,
		__newindex = function(t, key, value)
			if key == "item" then
				local counter = _counters.item[#_counters.item]
				if type(counter) == "string" then
					t[_counters.item[#_counters.item]] = value
				end
				return
			end
			_counters[key].value = value
			if _counters[key].refresh then
				for _, counter in ipairs(_counters[key].refresh) do
					t[counter] = 0
				end
			end
		end,
	}
	local counters = setmetatable({
		formatter = function(t, counter_name, heading)
			if counter_name == "item" then
				counter_name = _counters.item[#_counters.item]
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
			-- if type(counter_name) == "string" then
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
		-- end,
	}, counter_mate)
	for _, node in query:iter_captures(root, 0) do
		local node_type = node:type()
		if M.config.icon_formatter.heading[node_type] then
			counters[node_type] = counters[node_type] + 1
			local row, col = node:range()
			local curly_group_node = node:field("text")[1]
			local _, _, end_row, end_col = curly_group_node:range()
			local heading = curly_group_node:named_child(0)
					and vim.treesitter.get_node_text(curly_group_node:named_child(0), 0)
				or ""
			util.multichar_conceal(
				row,
				col,
				end_row,
				end_col,
				counters:formatter(node_type, heading),
				vim.api.nvim_create_namespace("latex_concealer")
			)
		end
		local enums = { "enumi", "enumii", "enumiii", "enumiv" }
		if node_type == "begin" then
			local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], 0)
			if env_name == "enumerate" then
				enum_depth = enum_depth + 1
				_counters.item[#_counters.item + 1] = enums[enum_depth]
				-- M.conceal_environment(node, true)
			elseif env_name == "itemize" then
				item_depth = item_depth + 1
				_counters.item[#_counters.item + 1] = item_depth
				-- M.conceal_environment(node, false)
			end
		end
		if node_type == "end" then
			local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], 0)
			if env_name == "enumerate" then
				counters.item = 0
				enum_depth = enum_depth - 1
				_counters.item[#_counters.item] = nil
				-- M.conceal_environment(node, true)
			elseif env_name == "itemize" then
				item_depth = item_depth - 1
				_counters.item[#_counters.item] = nil
				-- M.conceal_environment(node, false)
			end
		end
		if node_type == "enum_item" then
			if counters.item then
				counters.item = counters.item + 1
			end
			node = node:child(0)
			local row, col, end_row, end_col = node:range()
			vim.print(_counters)
			util.multichar_conceal(
				row,
				col,
				end_row,
				end_col,
				counters:formatter("item"),
				vim.api.nvim_create_namespace("latex_concealer")
			)
		end
	end
end
function M.refresh()
	local timer = vim.uv.new_timer()
	timer:start(
		200,
		0,
		vim.schedule_wrap(function()
			vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("latex_concealer"), 0, -1)
			M.conceal()
		end)
	)
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
	M.refresh()
	vim.opt_local.concealcursor = M.config.conceal_cursor
end
return M
