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
---parse args of latex include optional and args without brackets
---@param buffer number
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
	---@return LNode?,string
	local next_node = function()
		if #node_stack > 0 then
			local node = table.remove(node_stack)
			return node[1], node[2]
		end
		return iter()
	end
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
			local pss = parsers[node_type]
			while type(pss) == "function" do
				pss = pss(buffer, node, { last_node = temp_node })
			end
			if type(pss) == "table" and (pss.oarg or pss.narg) then
				pss = M.parse_args(node, field, pss.oarg, pss.narg)
			end
			if pss then
				if type(pss) == "function" then
					table.insert(parser_stack, pss)
					node = nil
				end
				if pss == true then
					node = nil
				end
			end
			local last_stacked_parser = parser_stack[#parser_stack]
			while last_stacked_parser and node do
				local try_parse = last_stacked_parser(node, field)
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
return M
