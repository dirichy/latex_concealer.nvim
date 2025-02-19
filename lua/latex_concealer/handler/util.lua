local M = {}
local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
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
		return { text, hilight }
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
		local arg_node = node:named_child(0)
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
		[1] = function(buffer, node, virt_text)
			local command_name = node:field("command")[1]
			local arg_nodes = node:field("arg")
			if not arg_nodes or not arg_nodes[1] then
				return
			end
			local start_row, start_col = command_name:range()
			local end_row, end_col = arg_nodes[1]:range()
			extmark.multichar_conceal(buffer, { start_row, start_col, end_row, end_col + 1 }, virt_text)
		end,
	}, {
		__index = function(t, key)
			local result = function(buffer, node, virt_text)
				local arg_nodes = node:field("arg")
				if not arg_nodes[key - 1] then
					return
				end
				local _, _, start_row, start_col = arg_nodes[key - 1]:range()
				local end_row, end_col
				start_col = start_col - 1
				if arg_nodes[key] then
					end_row, end_col = arg_nodes[key]:range()
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
return M
