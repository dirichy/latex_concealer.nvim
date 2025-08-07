local concealer = require("latex_concealer.processor.util")
local filters = require("latex_concealer.filters")
local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
local parser = require("latex_concealer.parser")
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
	local a, b = node:range()
	local c, d, e, f = curly_group_node:range()
	d = d + 1
	extmark.multichar_conceal(buffer, { a, b, c, d }, { counter.the(buffer, node_type), highlight[node_type] })
	extmark.multichar_conceal(buffer, { e, f - 1, e, f }, "")
end

M.config = {
	---@type table<string,LaTeX.Processor|fun(buffer,node):LaTeX.Processor?>
	processor = {
		math_delimiter = {
			after = function(buffer, node)
				local left_node = node:field("left_command")[1]
				local right_node = node:field("right_command")[1]
				extmark.multichar_conceal(buffer, { node = left_node }, "")
				extmark.multichar_conceal(buffer, { node = right_node }, "")
			end,
		},
		label_definition = {
			after = function(buffer, node)
				local row1, col1, row2, col2 = node:range()
				extmark.multichar_conceal(buffer, { row1, col1, row1, col1 + 7 }, { "🔖(", highlight.reference })
				extmark.multichar_conceal(buffer, { row2, col2 - 1, row2, col2 }, { ")", highlight.reference })
			end,
		},
		label_reference = {
			after = function(buffer, node)
				local row1, col1, row2, col2 = node:range()
				local text = vim.treesitter.get_node_text(node, buffer)
				local offset = string.find(text, "{")
				extmark.multichar_conceal(buffer, { row1, col1, row1, col1 + offset }, { "🔗(", highlight.reference })
				extmark.multichar_conceal(buffer, { row2, col2 - 1, row2, col2 }, { ")", highlight.reference })
			end,
		},
		subscript = {
			after = concealer.script(filters.subscript, highlight.script),
		},
		superscript = {
			after = concealer.script(filters.superscript, highlight.script),
		},
		generic_command = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer)
			local processor = M.config.processor_map.generic_command[command_name]
			if not processor then
				return
			end
			return processor
		end,
		command_name = {
			after = function(buffer, node)
				local command_name = vim.treesitter.get_node_text(node, buffer)
				local expanded = M.config.processor_map.command_name[command_name]
				if not expanded then
					return
				end
				if expanded then
					local range = { node = node }
					extmark.multichar_conceal(buffer, range, expanded)
					return
				end
			end,
		},
		chapter = { before = heading_handler },
		section = { before = heading_handler },
		subsection = { before = heading_handler },
		subsubsection = { before = heading_handler },
		math_environment = {
			before = function(buffer, node)
				util.set_if(buffer, "mmode", true)
			end,
			after = function(buffer, node)
				util.set_if(buffer, "mmode", false)
			end,
		},
		begin = {
			after = function(buffer, node)
				local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], buffer)
				if M.config.processor_map.begin[env_name] then
					return M.config.processor_map.begin[env_name](buffer, node)
				end
			end,
		},
		["end"] = {
			after = function(buffer, node)
				local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], buffer)
				if M.config.processor_map["end"][env_name] then
					return M.config.processor_map["end"][env_name](buffer, node)
				end
			end,
		},
		enum_item = {
			after = function(buffer, node)
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
		-- inline_formula = mmode_handler,
		["\\("] = {
			before = concealer.conceal("$", highlight.constant),
			after = function(buffer, node)
				util.set_if(buffer, "mmode", true)
			end,
		},
		["\\)"] = {
			before = concealer.conceal("$", highlight.constant),
			after = function(buffer, node)
				util.set_if(buffer, "mmode", false)
			end,
		},
		["\\["] = {
			after = function(buffer, node)
				util.set_if(buffer, "mmode", true)
			end,
		},
		["\\]"] = {
			after = function(buffer, node)
				util.set_if(buffer, "mmode", false)
			end,
		},
	},
	processor_map = {
		generic_command = require("latex_concealer.processor.generic_command"),
		command_name = require("latex_concealer.processor.command_name"),
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
	},
	extmark = {},
	conceal_cursor = "nvic",
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
	cursor_refresh_events = { "CursorMovedI", "CursorMoved" },
}

function M.conceal(buffer, root)
	-- query = query or vim.treesitter.query.parse("latex", query_string)
	if not M.enabled then
		return
	end
	if not root then
		if vim.api.nvim_buf_is_loaded(buffer) then
			local tree = vim.treesitter.get_parser(buffer, "latex")
			if tree and tree:trees() and tree:trees()[1] then
				root = tree:trees()[1]:root()
			end
		else
			return
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
	-- root = parser.parse_node_childrens(buffer, root)
	-- for node in root:iter_children() do
	for node, field in parser.iter_children(buffer, root) do
		-- local c, d = node:end_()
		-- local hook = util.cache[buffer].hook
		-- while #hook > 0 and (c > hook[#hook].pos[1] or c == hook[#hook].pos[1] and d > hook[#hook].pos[2]) do
		-- 	table.remove(hook).callback(buffer)
		-- end
		local node_type = node:type()
		---@type function|table|false
		local processor = M.config.processor[node_type]
		while type(processor) == "function" do
			processor = processor(buffer, node)
		end
		if processor and processor.init then
			processor = processor.init(buffer, node)
		end
		-- local flag = util.get_if(buffer, "_handler") and processor
		if processor then
			if processor.before then
				processor.before(buffer, node)
			end
		end
		M.conceal(buffer, node)
		if processor then
			if processor.after then
				processor.after(buffer, node)
			end
		end
	end
end

function M.refresh(buffer)
	vim.schedule(function()
		local t1 = vim.loop.hrtime()
		counter.reset_all(buffer)
		extmark.delete_all(buffer)
		util.reset_all(buffer)
		M.conceal(buffer)
		local t2 = vim.loop.hrtime()
		print(t2 - t1)
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
