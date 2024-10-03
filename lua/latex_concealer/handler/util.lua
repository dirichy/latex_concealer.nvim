local M = {}
local util = require("latex_concealer.extmark")
M.conceal = {
	delim = setmetatable({
		[1] = function(buffer, node, virt_text)
			local command_name = node:field("command")[1]
			local arg_nodes = node:field("arg")
			local start_row, start_col = command_name:range()
			local end_row, end_col = arg_nodes[1]:range()
			util.multichar_conceal(buffer, { start_row, start_col, end_row, end_col + 1 }, virt_text)
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
				return util.multichar_conceal(buffer, { start_row, start_col, end_row, end_col + 1 }, virt_text)
			end
			rawset(t, key, result)
			return result
		end,
	}),
	filter = setmetatable({
		[0] = function(buffer, node, filter, hilight, opts)
			opts = opts or {}
			local arg_nodes = node:field("arg")
			if not arg_nodes then
				return
			end
			local arg_node = arg_nodes[1]
			if not arg_node then
				return
			end
			local text = vim.treesitter.get_node_text(arg_node, buffer):sub(2, -2)
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
			return util.multichar_conceal(buffer, { node = node }, { text, hilight })
		end,
	}, {
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
				return util.multichar_conceal(buffer, { node = arg_nodes[key] }, { text, hilight })
			end
			rawset(t, key, result)
			return result
		end,
	}),
}
function M.conceal_commands(opts)
	opts.map = opts.map or {}
	opts.delim = opts.delim or {}
	local result = function(buffer, node)
		local command_name = node:field("command")[1]
		local arg_nodes = node:field("arg")
		if #arg_nodes + 1 < #opts.delim then
			return
		end
		local row1, col1 = command_name:range()
		local row1_end, col1_end, row2, col2
		for index, arg_node in ipairs(arg_nodes) do
			row1_end, col1_end, row2, col2 = arg_node:range()
			util.multichar_conceal(buffer, { row1, col1, row1_end, col1_end + 1 }, opts.delim[index] or "")
			if opts.map[index] then
				local text = vim.treesitter.get_node_text(arg_node, buffer):sub(2, -2)
				util.multichar_conceal(buffer, { row1_end, col1_end + 1, row2, col2 - 1 }, {
					string.gsub(text, ".", function(str)
						return opts.map[index][1] and opts.map[index][1][str] or str
					end),
					opts.map[index][2],
				})
			end
			row1 = row2
			col1 = col2 - 1
		end
		if opts.delim[#opts.delim] then
			util.multichar_conceal(buffer, { row1, col1 - 1, row1, col1 }, opts.delim[#opts.delim] or "")
		end
	end
	return result
end
return M
