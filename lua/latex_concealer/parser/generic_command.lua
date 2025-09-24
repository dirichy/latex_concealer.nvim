local extmark = require("latex_concealer.extmark")
local LNode = require("latex_concealer.lnode")
---@type table<string,function|LaTeX.Processor>
return {
	["verb"] = function(node, field, buffer)
		local lnode = LNode:new("generic_command")
		lnode:add_child(node:field("command")[1], "command")
		lnode:set_range(node)
		local arg_node = LNode:new("verb_group")
		local open = nil
		---@param nodee LNode?
		---@param fieldd string
		---@return LNode|LNode[]|nil if return nil, then this node is not finished, so we need to continue parse.
		---If return Lnode or LNode[], then this node is finished.
		return function(nodee, fieldd)
			if not nodee then
				return { { lnode, field } }
			end
			if not open then
				if nodee:type() == "word" then
					nodee = LNode:new(nodee)
					nodee._type = "char"
					local a, b, x = nodee:start()
					nodee:set_end(a, b + 1, x + 1)
				end
				open = vim.treesitter.get_node_text(nodee, buffer)
				if #open > 1 then
					return { { nodee, fieldd }, { lnode, field } }
				end
				arg_node:add_child(nodee, "open")
				arg_node:set_start(nodee)
				lnode:add_child(arg_node, "arg")
				return
			end
			local i = string.find(vim.treesitter.get_node_text(nodee, buffer), open, nil, true)
			local wordnode
			if nodee:type() == "word" and i then
				local a, b, x, c, d, y = nodee:range(true)
				if x + i < y then
					wordnode = LNode:new(nodee)
					wordnode:set_start(a, b + i, x + i)
				end
				nodee = LNode:new("char")
				nodee:set_range(a, b + i - 1, x + i - 1, a, b + i, x + i)
			end
			if open == vim.treesitter.get_node_text(nodee, buffer) then
				arg_node:add_child(nodee, "close")
				arg_node:set_end(nodee)
				lnode:set_end(nodee)
				local a, b, x = arg_node:start()
				local c, d, y = arg_node:end_()
				local verb_inner = LNode:new("verb_inner")
				verb_inner:set_range(a, b + 1, x + 1, c, d - 1, y - 1)
				if wordnode then
					return { { wordnode, fieldd }, { lnode, field } }
				end
				return { { lnode, field } }
			end
		end
	end,
	["not"] = { narg = 1 },
	["'"] = { narg = 1 },
	['"'] = { narg = 1 },
	["`"] = { narg = 1 },
	["="] = { narg = 1 },
	["~"] = { narg = 1 },
	["."] = { narg = 1 },
	["^"] = { narg = 1 },
	--command_delim
	["frac"] = { narg = 2 },
	["dfrac"] = { narg = 2 },
	["tfrac"] = { narg = 2 },
	["bar"] = { narg = 1 },
	["tilde"] = { narg = 1 },
	["norm"] = { narg = 1 },
	["abs"] = { narg = 1 },
	["sqrt"] = { oarg = true, narg = 2 },
}
