---@class LaTeX.Processor
---@field grid (fun(buffer:integer,lnode:LNode):Grid)|nil
---@field init (fun(buffer:integer,node:LNode):LaTeX.Processor?)?
---@field parser (fun(buffer:integer,node:LNode,field:string):LaTeX.Parser?)? You can make your own parser here for some node like `\verb'.
---@field oarg boolean? I have made a parser for optional arg and arg whih no curly brackets, set oarg to true will try to parser an optional arg with `[]`
---@field narg integer? set `narg` to a number to define the number of args, optional includes. If `narg` is nil, the parser will only try to find args with curly brackets.
---@field before ( fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil )? will be called before all children of `node` are processed
---@field after (fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil)? will be called after all children of `node` are processed

local concealer = require("latex_concealer.processor.util")
local filters = require("latex_concealer.filters")
local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
local Grid = require("latex_concealer.grid")
local parser = require("latex_concealer.parser")
local LNode = require("latex_concealer.lnode")

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

local M = {}
M.parser = {
	generic_command = function(buffer, node, opts)
		local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer):sub(2, -1)
		local processor = M.map.generic_command[command_name]
		while type(processor) == "function" do
			processor = processor(buffer, node)
		end
		return processor
	end,
	superscript = function(buf, snode, opts)
		local last_node = opts.last_node
		local node1 = last_node[1]
		local lnode = LNode:new(snode:type())
		lnode:set_start(node1)
		lnode:set_end(snode)
		lnode:add_child(node1, "base")
		lnode:add_child(snode:child(0), "operator")
		lnode:add_child(snode:child(1), "script")
		last_node[1] = lnode
		return true
	end,
	subscript = function(buf, snode, opts)
		local last_node = opts.last_node
		local node1 = last_node[1]
		local lnode = LNode:new(snode:type())
		lnode:set_start(node1)
		lnode:set_end(snode)
		lnode:add_child(node1, "base")
		lnode:add_child(snode:child(0), "operator")
		lnode:add_child(snode:child(1), "script")
		last_node[1] = lnode
		return true
	end,
}
M.processor = {
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
		grid = function(buffer, node)
			local base = node:field("base")[1]
			local script = LNode:new(node:field("script")[1]):remove_bracket()
			script = M.node2grid(buffer, script)
			local ss = Grid:new(script)
			local flag = false
			if script.height == 1 then
				flag = true
				for index, value in ipairs(script.data[1]) do
					flag = filters.all_match(value[1], filters.subscript)
					if not flag then
						break
					end
					ss.data[1][index][1] = flag
				end
			end
			return flag and M.node2grid(buffer, base) + ss or M.node2grid(buffer, base) % script
		end,
	},
	superscript = {
		after = concealer.script(filters.superscript, highlight.script),
		grid = function(buffer, node)
			local base = node:field("base")[1]
			local script = LNode:new(node:field("script")[1]):remove_bracket()
			script = M.node2grid(buffer, script)
			local ss = Grid:new(script)
			local flag = false
			if script.height == 1 then
				flag = true
				for index, value in ipairs(script.data[1]) do
					flag = filters.all_match(value[1], filters.superscript)
					if not flag then
						break
					end
					ss.data[1][index][1] = flag
				end
			end
			return flag and M.node2grid(buffer, base) + ss or M.node2grid(buffer, base) ^ script
		end,
	},
	generic_command = function(buffer, node)
		local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer):sub(2, -1)
		local processor = M.map.generic_command[command_name]
		while type(processor) == "function" do
			processor = processor(buffer, node)
		end
		if not processor then
			return
		end
		if processor.processor then
			processor = vim.tbl_extend("force", processor, processor.processor(buffer, node) or {})
		end
		return processor
	end,
	command_name = {
		grid = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node, buffer):sub(2, -1)
			if M.map.command_name[command_name] then
				return Grid:new(M.map.command_name[command_name])
			end
		end,
		after = function(buffer, node)
			local command_name = vim.treesitter.get_node_text(node, buffer):sub(2, -1)
			local expanded = M.map.command_name[command_name]
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
			if M.map.begin[env_name] then
				return M.map.begin[env_name](buffer, node)
			end
		end,
	},
	["end"] = {
		after = function(buffer, node)
			local env_name = vim.treesitter.get_node_text(node:field("name")[1]:field("text")[1], buffer)
			if M.map["end"][env_name] then
				return M.map["end"][env_name](buffer, node)
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
	inline_formula = function(buffer, node) end,
}

M.map = {
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
}

function M.node2grid(buffer, node)
	local pss = M.processor[node:type()]
	while type(pss) == "function" do
		pss = pss(buffer, node)
	end
	if pss and pss.grid then
		return pss.grid(buffer, node) or M.default_grid_processor(buffer, node)
	end
	return M.default_grid_processor(buffer, node)
end

function M.default_grid_processor(buffer, node)
	local g = Grid:new()
	if not node:child(0) then
		return Grid:new({ vim.treesitter.get_node_text(node, buffer), "MathZone" })
	else
		for n in parser.iter_children(buffer, node, M.parser) do
			g = g + M.node2grid(buffer, n)
		end
	end
	return g
end

concealer.node2grid = M.node2grid
concealer.default_grid_processor = M.default_grid_processor

function M.setup(opts) end
return M
