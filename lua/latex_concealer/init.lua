local concealer = require("latex_concealer.processor.util")
local processor = require("latex_concealer.processor")
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

M.config = {
	---@type table<string,LaTeX.Processor|fun(buffer,node):LaTeX.Processor?>
	processor = {},
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
	for node, field in parser.iter_children(buffer, root, processor.parser) do
		local node_type = node:type()
		---@type function|table|false
		local pss = processor.processor[node_type]
		while type(pss) == "function" do
			pss = pss(buffer, node)
		end
		-- if pss and pss.processor then
		-- 	pss = pss.processor(buffer, node)
		-- end
		-- local flag = util.get_if(buffer, "_handler") and processor
		if pss then
			if pss.before then
				pss.before(buffer, node)
			end
		end
		M.conceal(buffer, node)
		if pss then
			if pss.after then
				pss.after(buffer, node)
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
	processor.setup(M.config.processor)
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
	vim.keymap.set("n", "K", function()
		local math_node = require("latex_concealer.conditions.luasnip")._in_math()
		if math_node then
			require("latex_concealer.processor").node2grid(vim.api.nvim_win_get_buf(0), math_node):show()
		else
			vim.api.nvim_exec2("Lspsaga hover_doc", {})
		end
	end)
end

return M
