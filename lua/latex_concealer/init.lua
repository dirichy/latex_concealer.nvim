local concealer = require("latex_concealer.handler.util").conceal
local filters = require("latex_concealer.filters")
local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
local M = {}
M.enabled = true
function M.toggle()
	M.enabled = not M.enabled
	M.refresh(vim.api.nvim_win_get_buf(0))
end
M.have_setup = {}
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
		if result.node then
			node = result.node
		end
		if result.font then
			return concealer.font(buffer, node, result.font[1], result.font[2], result.font.opts)
		end
		if result.delim then
			counter.step_counter_rangal(buffer, "_bracket", node)
			for k, v in ipairs(result.delim) do
				concealer.delim[k](buffer, node, v, result.delim.include_optional)
			end
		end
		if result.filter then
			for k, v in pairs(result.filter) do
				concealer.filter[k](buffer, node, v)
			end
		end
		if result.conceal then
			extmark.multichar_conceal(buffer, { node = node }, result.conceal)
		end
	end
end
M.config = {
	processor = {
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
		generic_command = {
			init = function(buffer, node)
				local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer)
				local processor = M.config.handler.generic_command[command_name]
				if not processor then
					return false
				end
				if type(processor) == "function" then
					processor = { after = processor }
				end
				if processor.oarg or processor.narg then
					node = util.parse_args(buffer, node, processor.oarg, processor.narg)
				end
				if processor.init then
					processor = processor.init(buffer, node)
				end
				return processor, node
			end,
			-- before = function(buffer, node)
			-- 	if cmd.begin then
			-- 		cmd.begin(buffer, node)
			-- 	end
			-- 	local expanded
			-- 	if M.config.handler.generic_command[command_name] then
			-- 		expanded = command_expand(buffer, command_name, node)
			-- 	end
			-- 	if expanded then
			-- 		extmark.multichar_conceal(buffer, { node = node }, expanded)
			-- 	end
			-- end,
			-- after = function(buffer, node)
			-- 	local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer)
			-- 	local cmd = M.config.handler.generic_command[command_name]
			-- 	if not cmd then
			-- 		return
			-- 	end
			-- 	if cmd["end"] then
			-- 		cmd["end"](buffer, node)
			-- 	end
			-- end,
		},
		command_name = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node, buffer)
			local expanded = M.config.handler.command_name[command_name]
			if not expanded then
				return
			end
			if expanded then
				local range = { node = node }
				extmark.multichar_conceal(buffer, range, expanded)
				return
			end
		end,
		chapter = { before = heading_handler },
		section = { before = heading_handler },
		subsection = { before = heading_handler },
		subsubsection = { before = heading_handler },
		begin = function(buffer, node)
			local parent = node:parent()
			if parent and parent:type() == "math_environment" then
				util.set_if(buffer, "mmode", true)
				return
			end
			local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], buffer)
			if M.config.handler.begin[env_name] then
				return M.config.handler.begin[env_name](buffer, node)
			end
		end,
		["end"] = function(buffer, node)
			local parent = node:parent()
			if parent and parent:type() == "math_environment" then
				util.set_if(buffer, "mmode", false)
				return
			end
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
		-- inline_formula = mmode_handler,
		["\\("] = function(buffer, node)
			util.set_if(buffer, "mmode", true)
		end,
		["\\)"] = function(buffer, node)
			util.set_if(buffer, "mmode", false)
		end,
		["\\["] = function(buffer, node)
			util.set_if(buffer, "mmode", true)
		end,
		["\\]"] = function(buffer, node)
			util.set_if(buffer, "mmode", false)
		end,
		-- displayed_equation = mmode_handler,
		-- math_environment = mmode_handler,
	},
	handler = {
		generic_command = require("latex_concealer.handler.generic_command"),
		command_name = require("latex_concealer.handler.command_name"),
		chapter = {},
		section = {},
		subsection = {},
		subsubsection = {},
		inline_formula = {},
		displayed_equation = {},
		math_environment = {},
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

-- local query_string = ""
-- for k, _ in pairs(M.config._handler) do
-- 	query_string = query_string .. " (" .. k .. ") @" .. k
-- end
-- local query
function M.conceal(buffer, root)
	-- query = query or vim.treesitter.query.parse("latex", query_string)
	if not M.enabled then
		return
	end
	if not root then
		local tree = vim.treesitter.get_parser(buffer, "latex")
		if tree and tree:trees() and tree:trees()[1] then
			root = tree:trees()[1]:root()
			-- else
			-- return
		end
	end
	-- counter.reset_all(buffer)
	-- for _, node in query:iter_captures(root, buffer) do
	if not root then
		vim.defer_fn(function()
			M.conceal(buffer)
		end, 1000)
		return
	end
	for node in root:iter_children() do
		local _, _, c, d = vim.treesitter.get_node_range(node)
		local hook = util.cache[buffer].hook
		while #hook > 0 and (c > hook[#hook].pos[1] or c == hook[#hook].pos[1] and d > hook[#hook].pos[2]) do
			table.remove(hook).callback(buffer)
		end
		local node_type = node:type()
		---@type function|table|false
		local processor = M.config.processor[node_type]
		if type(processor) == "function" then
			processor = { after = processor }
		end
		local a, b
		if util.get_if(buffer, "_handler") and processor then
			if processor.init then
				a, b = processor.init(buffer, node)
				processor = a or processor
			end
			if processor.before then
				processor.before(buffer, b or node)
			end
		end
		M.conceal(buffer, node)
		node = b or node
		if util.get_if(buffer, "_handler") and processor then
			if processor.after then
				if type(node) == "table" then
					util.hook(buffer, node, function()
						processor.after(buffer, node)
					end)
				else
					processor.after(buffer, node)
				end
				-- if result then
				-- 	if type(result) ~= "table" then
				-- 		result = { conceal = result }
				-- 	end
				-- 	if result.font then
				-- 		return concealer.font(buffer, node, result.font[1], result.font[2], result.font.opts)
				-- 	end
				-- 	if result.delim then
				-- 		counter.step_counter_rangal(buffer, "_bracket", node)
				-- 		for k, v in ipairs(result.delim) do
				-- 			concealer.delim[k](buffer, node, v, result.delim.include_optional)
				-- 		end
				-- 	end
				-- 	if result.filter then
				-- 		for k, v in pairs(result.filter) do
				-- 			concealer.filter[k](buffer, node, v)
				-- 		end
				-- 	end
				-- 	if result.conceal then
				-- 		extmark.multichar_conceal(buffer, { node = node }, result.conceal)
				-- 	end
				-- end
			end
		end
	end
end

function M.refresh(buffer)
	vim.schedule(function()
		counter.reset_all(buffer)
		extmark.delete_all(buffer)
		util.reset_all(buffer)
		M.conceal(buffer)
	end)
end

M.cursor_refresh = function(buffer)
	extmark.restore_and_gc(buffer)
end

M.local_refresh = M.refresh

--- init for a buffer
---@param buffer table|number
function M.setup_buf(buffer)
	if M.have_setup[buffer] then
		return
	end
	buffer = buffer and (type(buffer) == "number" and buffer or buffer.buf) or vim.api.nvim_get_current_buf()
	M.have_setup[buffer] = true
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
	util.setup_buf(buffer)
	vim.defer_fn(function()
		M.refresh(buffer)
	end, 1000)
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
	vim.schedule(function()
		M.setup_buf({ buf = vim.api.nvim_get_current_buf() })
	end)
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.tex",
		callback = function(buffer)
			vim.schedule(function()
				M.setup_buf(buffer)
			end)
		end,
	})
end

return M
