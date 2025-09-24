---@alias LaTeX.Parser fun(node:LNode?,field:string?):LNode|LNode[]|nil
local LNode = require("latex_concealer.lnode")
-- local handler = require("latex_concealer.processor")
-- local utf8 = require("lua-utf8")
local M = {}

---@param text_lnode LNode
---@return fun():LNode
local function iter_remove_word_of_text(text_lnode)
	return function()
		table.remove(text_lnode._field.word, 1)
		return table.remove(text_lnode._childrens, 1)
	end
end
M.map = {
	generic_command = require("latex_concealer.parser.generic_command"),
}

M.parser = {
	generic_command = function(buffer, node, opts)
		local command_name = vim.treesitter.get_node_text(node:field("command")[1], buffer):sub(2, -1)
		local parser = M.map.generic_command[command_name]
		if not parser then
			return
		end
		if type(parser) == "table" then
			parser = M.parse_args(node, opts.field, parser.oarg, parser.narg)
		else
			parser = parser(node, opts.field, buffer)
		end
		return parser
	end,
	superscript = function(buf, snode, opts)
		if snode:field("base")[1] then
			return
		end
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
		if snode:field("base")[1] then
			return
		end
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
---parse args of latex include optional and args without brackets
---@param command_node LNode The generic_command node to find it's args
---@param optional boolean If we should try to find an optional arg with brack
---@param number number? The number of args, including optional arg. default is 1.
---@return fun(LNode:LNode?,field:string?):LNode?|nil parser if return nil, then the command don't need to parse.
---If return a function, then following node will pass to it and the function need to parse.
function M.parse_args(command_node, field, optional, number)
	---@type _LNode
	optional = optional and true or false
	local narg_without_oarg
	if optional then
		narg_without_oarg = number and number - 1 or 0
	else
		narg_without_oarg = number or 0
	end
	local lnode = LNode:new(command_node)
	local args = lnode:field("arg")
	if #args > 0 then
		if #args >= narg_without_oarg then
			return
		end
		optional = false
	end

	---@param node LNode?
	---@param fieldd string
	---@return LNode|LNode[]|nil if return nil, then this node is not finished, so we need to continue parse.
	---If return Lnode or LNode[], then this node is finished.
	return function(node, fieldd)
		--If there is not sibling then end parse
		if not node then
			return { lnode, field }
		end
		--If we need to find an optional arg
		if optional then
			-- local optional = lnode:field("optional_arg")
			-- if optional then
			-- 	optional = optional[1]
			-- end
			--If we didn't find "[" for optional arg
			if optional == true then
				if node:type() == "[" then
					optional = LNode:new("brack_group")
					optional._childrens[1] = node
					optional:set_range(node)
					lnode:add_child(optional, "optional_arg")
					lnode:set_end(node)
					return
				end
				--If there is no "[", we set optional to false and goto find normal arg.
				--Since number include optional arg
				optional = false
				goto arg
			end
			--If we've find "[", we need to add node into the optional arg.
			optional:add_child(node)
			optional:set_end(node)
			lnode:set_end(node)
			--If the next node is "]", the optional arg is finished.
			if node:type() == "]" then
				optional = false
			end
			return nil
		end
		::arg::
		--If number=0, then we only accept curly group infinite times.
		if
			string.match(node:type(), "^curly_group")
			and (narg_without_oarg <= 0 or #lnode:field("arg") < narg_without_oarg)
		then
			lnode:add_child(node, "arg")
			lnode:set_end(node)
		else
			if node:type() == "word" then
				local word = LNode:new(node)
				local a, b, x, c, d, y = word:range(true)
				--If the length is 1, then just add it as a arg node.
				--Else we need to split it.
				while #lnode:field("arg") < narg_without_oarg and b < d do
					local arg_node = LNode:new("char")
					arg_node._range = { a, b, x, a, b + 1, x + 1 }
					lnode:add_child(arg_node, "arg")
					lnode:set_end(arg_node)
					b = b + 1
					x = x + 1
				end
				if b < d then
					word:set_start(a, b, x)
					return { { word, fieldd }, { lnode, field } }
				else
					if #lnode:field("arg") >= narg_without_oarg then
						return { lnode, field }
					end
					return
				end
			else
				lnode:add_child(node, "arg")
				lnode:set_end(node)
			end
		end
		-- Tf we've find enough arg, then return lnode to end
		if #lnode:field("arg") >= narg_without_oarg then
			return { lnode, field }
		end
		return nil
	end
end

function M.iter_children(buffer, pnode, parsers)
	local parser_stack = {}
	local node_stack = {}
	local temp_node = {}
	local iter = pnode:iter_children()
	---@return LNode,string
	local next_node = function()
		if #node_stack > 0 then
			local node = table.remove(node_stack)
			return node[1], node[2]
		end
		return iter()
	end
	---@return LNode,string
	return function()
		local node, field = next_node()
		while node do
			local node_type = node:type()
			if node_type == "text" then
				local index = #node_stack + 1
				for n, t in node:iter_children() do
					table.insert(node_stack, index, { n, nil })
				end
				node, field = next_node()
				if not node then
					break
				end
				node_type = node:type()
			end
			local parser = M.parser[node_type]
			parser = parser and parser(buffer, node, { last_node = temp_node, field = field })
			if parser then
				if type(parser) == "function" then
					table.insert(parser_stack, parser)
					node = nil
				end
				if parser == true then
					node = nil
				end
			end
			local last_stacked_parser = parser_stack[#parser_stack]
			while last_stacked_parser and node do
				local try_parse = last_stacked_parser(node, field, buffer)
				node, field = nil, nil
				if try_parse then
					table.remove(parser_stack)
					last_stacked_parser = parser_stack[#parser_stack]
					if type(try_parse[2]) == "string" then
						node, field = unpack(try_parse)
					elseif not try_parse[1] then
						node, field = try_parse, nil
					else
						for _, value in ipairs(try_parse) do
							table.insert(node_stack, value[1] and value or { value, nil })
						end
						node, field = next_node()
					end
				end
			end
			if node then
				if temp_node[1] then
					local nnn, fff = unpack(temp_node)
					temp_node = { node, field }
					return nnn, fff
				else
					temp_node = { node, field }
				end
			end
			node, field = next_node()
		end
		if temp_node[1] then
			local nnn, fff = unpack(temp_node)
			temp_node = {}
			return nnn, fff
		end
	end
end
--- parse all children of the node
---@param buffer integer
---@param pnode LNode
---@return LNode
function M.parse_node_childrens(buffer, pnode, parsers)
	local lnode = LNode:new(pnode:type())
	lnode:set_range(pnode)
	for node, field in M.iter_children(buffer, pnode, parsers) do
		lnode:add_child(node, field)
	end
	return lnode
end

---@param parent Range4|LNode
---@param child Range4|LNode
---@return boolean
local function RcoverR(parent, child)
	local a1, a2, b1, b2, c1, c2, d1, d2
	if parent[1] then
		a1, b1, c1, d1 = unpack(parent)
	else
		a1, b1, c1, d1 = parent:range()
	end
	if child[1] then
		a2, b2, c2, d2 = unpack(child)
	else
		a2, b2, c2, d2 = child:range()
	end
	return (a1 < a2 or a1 == a2 and b1 <= b2) and (c2 < c1 or c2 == c1 and d2 <= d1)
end
--- get all node cover the range as an array, aseding.
---@param buffer integer
---@param range Range4|LNode|nil
---@param root LNode if provided, will only find all Descendants of root.
function M.get_node(range, buffer, root, parsers)
	buffer = buffer or vim.api.nvim_win_get_buf(0)
	if not range then
		local a, b = unpack(vim.api.nvim_win_get_cursor(0))
		a = a - 1
		range = { a, b, a, b + 1 }
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
	if not RcoverR(root, range) then
		return
	end
	local result = { root }
	local cur_node = root
	while cur_node do
		local flag = false
		for node, _ in M.iter_children(buffer, cur_node, parsers) do
			if RcoverR(node, range) then
				cur_node = node
				flag = true
				break
			end
		end
		if flag then
			table.insert(result, cur_node)
		else
			break
		end
	end
	return result
end
return M
