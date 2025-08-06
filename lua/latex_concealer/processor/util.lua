local M = {}
local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
M.conceal = {
	font = function(buffer, node, filter, hilight, opts)
		opts = opts or {}
		local arg_nodes = node:field("arg")
		if not arg_nodes then
			return
		end
		local arg_node = arg_nodes[1]
		if not arg_node then
			return
		end
		local text = vim.treesitter.get_node_text(arg_node, buffer)
		if string.match(arg_node:type(), "curly_group") then
			text = text:sub(2, -2)
		end
		if type(filter) == "table" then
			local fil_table = filter
			filter = function(str)
				return str:gsub("(\\[a-zA-Z]*)", function(atom)
					return fil_table[atom]
				end):gsub("(.)", function(atom)
					return fil_table[atom]
				end)
			end
		end
		text = filter(text)
		if opts.delim then
			text = opts.delim[1] .. text .. opts.delim[2]
		end
		extmark.multichar_conceal(buffer, { node = node }, { text, hilight })
	end,
	--- Handle subscript and super script
	---@param buffer number
	---@param node TSNode
	---@param filter table # the value is concealed char of key
	---@param hilight string # hilight group
	---@return any
	script = function(buffer, node, filter, hilight)
		if not util.get_if(buffer, "mmode") then
			return
		end
		local arg_node = node:field("superscript")[1] or node:field("subscript")[1]
		if not arg_node then
			return
		end
		local text = vim.treesitter.get_node_text(arg_node, buffer)
		if string.match(arg_node:type(), "curly_group") then
			text = text:sub(2, -2)
		end
		local flag = true
		text = text:gsub("(.)", function(letter)
			if filter[letter] then
				return filter[letter]
			else
				flag = false
				return letter
			end
		end)
		return flag and extmark.multichar_conceal(buffer, { node = node }, { text, hilight }) or false
	end,
	delim = setmetatable({
		[1] = function(buffer, node, virt_text, include_optional)
			if include_optional == nil then
				include_optional = true
			end
			local command_name = node:field("command")[1]
			local arg_nodes = node:field("optional_arg")
			if not arg_nodes or not arg_nodes[1] or not include_optional then
				arg_nodes = node:field("arg")
				if not arg_nodes or not arg_nodes[1] then
					return
				end
			end
			local start_row, start_col = command_name:range()
			local end_row, end_col = arg_nodes[1]:range()
			extmark.multichar_conceal(buffer, { start_row, start_col, end_row, end_col + 1 }, virt_text)
		end,
		[2] = function(buffer, node, virt_text, include_optional)
			if include_optional == nil then
				include_optional = true
			end
			local t = 1
			local arg_nodes = node:field("optional_arg")
			if not arg_nodes or not arg_nodes[1] or not include_optional then
				t = 2
				arg_nodes = node:field("arg")
				if not arg_nodes or not arg_nodes[1] then
					return
				end
			end
			local start_row, start_col = arg_nodes[1]:end_()
			start_col = start_col - 1
			arg_nodes = node:field("arg")
			local end_row, end_col
			if not arg_nodes or not arg_nodes[t] then
				end_row, end_col = start_row, start_col
			else
				end_row, end_col = arg_nodes[t]:start()
			end

			extmark.multichar_conceal(buffer, { start_row, start_col, end_row, end_col + 1 }, virt_text)
		end,
	}, {
		__index = function(t, key)
			local result = function(buffer, node, virt_text, include_optional)
				local index = key
				if include_optional == nil then
					include_optional = true
				end
				local arg_nodes = node:field("optional_arg")
				if arg_nodes and arg_nodes[1] and include_optional then
					index = key - 1
				end
				arg_nodes = node:field("arg")
				if not arg_nodes[index - 1] then
					return
				end
				local _, _, start_row, start_col = arg_nodes[index - 1]:range()
				local end_row, end_col
				start_col = start_col - 1
				if arg_nodes[index] then
					end_row, end_col = arg_nodes[index]:range()
				else
					end_row = start_row
					end_col = start_col
				end
				return extmark.multichar_conceal(buffer, { start_row, start_col, end_row, end_col + 1 }, virt_text)
			end
			rawset(t, key, result)
			return result
		end,
	}),
	filter = setmetatable({}, {
		__index = function(t, key)
			local result = function(buffer, node, filter, hilight)
				---@type TSNode[]
				local arg_nodes = node:field("arg")
				if not arg_nodes[key] then
					return
				end
				local text = vim.treesitter.get_node_text(arg_nodes[key], buffer):sub(2, -2)
				if type(filter) == "table" then
					local fil_table = filter
					filter = function(str)
						return str:gsub("(\\[a-zA-Z]*)", function(atom)
							return fil_table[atom]
						end):gsub("(.)", function(atom)
							return fil_table[atom]
						end)
					end
				end
				text = filter(text)
				return extmark.multichar_conceal(buffer, { node = arg_nodes[key] }, { text, hilight })
			end
			rawset(t, key, result)
			return result
		end,
	}),
}

M.delim = function(...)
	local args = { ... }
	local include_optional = args[#args]
	if type(include_optional) == "boolean" then
		args[#args] = nil
	end
	for k, v in ipairs(args) do
		if type(v) == "string" then
			args[k] = { v, highlight.delim }
		end
	end
	return {
		before = function(buffer, node)
			counter.step_counter(buffer, "_bracket")
			for k, v in ipairs(args) do
				M.conceal.delim[k](buffer, node, v, include_optional)
			end
		end,
		after = function(buffer, node)
			counter.reverse_counter(buffer, "_bracket")
		end,
	}
end

M.font = function(filter, hl)
	hl = hl or highlight.default
	return function(buffer, node)
		return M.conceal.font(buffer, node, filter, hl)
	end
end

local function get_hl_group(buffer, x, y)
	if x and type(x) ~= "number" then
		if x:type() == "char" then
			x, y = x:start()
		else
			x, y = x:start()
			y = y + 1
		end
	end
	local ins = vim.inspect_pos(buffer, x, y)
	ins = ins.treesitter[#ins.treesitter]
	return ins and ins.hl_group_link or "Normal"
end
M.modify_next_char = function(modifier, hl, force_hl)
	if type(modifier) == "string" then
		local s = modifier
		local f = function(str)
			return str .. s
		end
		modifier = f
	end
	hl = hl or highlight.default
	return {
		narg = 1,
		after = function(buffer, node)
			local arg1 = node:field("arg")[1]
			local a, b, c, d = node:range()
			local mark =
				vim.api.nvim_buf_get_extmarks(buffer, extmark.config.ns_id, { a, b }, { c, d }, { details = true })[1]
			local virt_text = mark and mark[4].virt_text[1]
			if virt_text then
				virt_text[1] = modifier(virt_text[1])
				virt_text[2] = force_hl and (hl or highlight.default) or virt_text[2]
				extmark.multichar_conceal(buffer, { node = node }, virt_text, { id = mark[1] })
				return
			end
			if not arg1 then
				return
			end
			local nextchar = vim.treesitter.get_node_text(arg1, buffer)
			if arg1:type() == "char" then
				return extmark.multichar_conceal(
					buffer,
					{ node = node },
					{ modifier(nextchar), {} },
					{ hl_mode = "combine" }
				)
			elseif arg1:type():match("^curly_group") and #nextchar == 3 then
				return extmark.multichar_conceal(
					buffer,
					{ node = node },
					{ modifier(nextchar:sub(2, -2)), {} },
					{ hl_mode = "combine" }
				)
			end
		end,
	}
end

return M
