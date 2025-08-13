---@alias LNode _LNode|TSNode
---@class _LNode
---@field _range Range6
---@field _field table <string,LNode[]>
---@field _childrens LNode[]
---@field _type string
local _LNode = {
	_field = {},
	_childrens = {},
	_type = "",
}
_LNode.__index = _LNode

--- Returns a list of all the node's children that have the given field name.
--- @param name string
--- @return LNode[]
function _LNode:field(name)
	return self._field[name] or {}
end
--- return type
---@return string
function _LNode:type()
	return self._type
end

-- --- @return _LNode?
-- function _LNode:parent()
-- 	return self._parent
-- end

--- Get the node's next sibling.
-- --- @return LNode?
-- function _LNode:next_sibling()
-- 	return self:parent()._childrens[self._index + 1]
-- end

--- Get the node's previous sibling.
-- --- @return LNode?
-- function _LNode:prev_sibling()
-- 	return self:parent()._childrens[self._index - 1]
-- end

-- --- Get the node's next named sibling.
-- --- @return _LNode?
-- function _LNode:next_named_sibling() end
--
-- --- Get the node's previous named sibling.
-- --- @return _LNode?
-- function _LNode:prev_named_sibling() end

-- Iterates over all the direct children of {_LNode}, regardless of whether
-- they are named or not.
-- Returns the child node plus the eventual field name corresponding to this
-- child node.
--- @return fun(): LNode?
function _LNode:iter_children()
	local index = 0
	return function()
		index = index + 1
		return self._childrens[index]
	end
end

--- Get the node's number of children.
--- @return integer
function _LNode:child_count()
	return #self._childrens
end

--- Get the node's child at the given {index}, where zero represents the first
--- child.
--- @param index integer
--- @return LNode?
function _LNode:child(index)
	if index >= 0 then
		return self._childrens[index + 1]
	else
		return self._childrens[#self._childrens + index]
	end
end

--Used to debug
function _LNode:tostring(indent)
	indent = indent or 0
	local str = "(" .. self:type()
	for _ = 1, indent do
		str = "  " .. str
	end
	if self:child(0) then
		str = str .. string.format(" ; [%d,%d] - [%d,%d]\n", self:range())
		for node in _LNode.iter_children(self) do
			node = _LNode:new(node)
			str = str .. node:tostring(indent + 1)
		end
		str = str .. ")"
	else
		str = str .. string.format(") ; [%d,%d] - [%d,%d]", self:range())
	end
	return str
end

-- --- Get the node's number of named children.
-- --- @return integer
-- function _LNode:named_child_count() end
--
-- --- Returns a list of the node's named children.
-- --- @return _LNode[]
-- function _LNode:named_children() end
--
--- Check if the node has any of the given node types as its ancestor.
-- --- @param node_types string[]
-- --- @return boolean
-- function _LNode:__has_ancestor(node_types) end

--- Get the node's named child at the given {index}, where zero represents the
--- first named child.
-- --- @param index integer
-- --- @return _LNode?
-- function _LNode:named_child(index) end

--- Get the node's child that contains {descendant} (includes {descendant}).
---
--- For example, with the following node hierarchy:
---
--- ```
--- a -> b -> c
---
--- a:child_with_descendant(c) == b
--- a:child_with_descendant(b) == b
--- a:child_with_descendant(a) == nil
--- ```
-- --- @param descendant _LNode
-- --- @return _LNode?
-- function _LNode:child_with_descendant(descendant) end

--- Get the node's start position. Return three values: the row, column and
--- total byte count (all zero-based).
--- @return integer, integer,integer
function _LNode:start()
	return self._range[1], self._range[2], self._range[3]
end

--- Get the node's end position. Return three values: the row, column and
--- total byte count (all zero-based).
--- @return integer, integer,integer
function _LNode:end_()
	return self._range[4], self._range[5], self._range[6]
end

--- Get the range of the node.
---
--- Return four or six values:
---
--- - start row
--- - start column
--- - start byte (if {include_bytes} is `true`)
--- - end row
--- - end column
--- - end byte (if {include_bytes} is `true`)
--- @return integer, integer, integer, integer
--- @overload fun(include_bytes:true): integer, integer, integer, integer,integer,integer
function _LNode:range(include_bytes)
	if include_bytes then
		return self._range[1], self._range[2], self._range[3], self._range[4], self._range[5], self._range[6]
	end
	return self._range[1], self._range[2], self._range[4], self._range[5]
end
--
--
function _LNode:set_range(a, b, x, c, d, y)
	if type(a) == "userdata" then
		a, b, x, c, d, y = a:range(true)
	end
	if type(a) == "table" then
		self._range = a._range and a._range or a
		return
	end
	self._range = { a, b, x, c, d, y }
end

function _LNode:set_start(a, b, x)
	if type(a) == "userdata" then
		a, b, x = a:start()
	end
	if type(a) == "table" then
		if a._range then
			a, b, x = a:start()
		else
			a, b, x = a[1], a[2], a[3]
		end
	end
	self._range[1] = a
	self._range[2] = b
	self._range[3] = x
end

function _LNode:set_end(a, b, x)
	if type(a) == "userdata" then
		a, b, x = a:end_()
	end
	if type(a) == "table" then
		if a._range then
			a, b, x = a:end_()
		else
			a, b, x = a[4], a[5], a[6]
		end
	end
	self._range[4] = a
	self._range[5] = b
	self._range[6] = x
end

--- Check if {node} refers to the same node within the same tree.
--- @param node _LNode
--- @return boolean
function _LNode:equal(node)
	return self == node
end

---@param node_type string|LNode?
---@return _LNode
function _LNode:new(node_type, opt)
	if type(node_type) == "userdata" then
		local lnode = setmetatable({ _type = node_type:type(), _childrens = {}, _field = {}, _range = {} }, _LNode)
		lnode:set_range(node_type)
		for node, field in node_type:iter_children() do
			lnode._childrens[#lnode._childrens + 1] = node
			if field then
				lnode._field[field] = lnode._field[field] or {}
				table.insert(lnode._field[field], node)
			end
		end
		return lnode
	end
	if type(node_type) == "table" then
		return node_type
	end
	return setmetatable({ _type = node_type or "", _childrens = {}, _field = {}, _range = {} }, _LNode)
end

function _LNode:add_child(child, field, index)
	-- child = _LNode:new(child)
	if index then
		table.insert(self._childrens, index, child)
	else
		table.insert(self._childrens, child)
	end
	-- child._parent = self
	if field then
		self._field[field] = self._field[field] or {}
		table.insert(self._field[field], child)
	end
end

function _LNode:shift_range(a, b, x, c, d, y)
	if type(a) == "number" then
		if y then
			a = { a, b, x, c, d, y }
		else
			a = { a, b, b, c, d, d }
		end
	end
	for index, value in ipairs(a) do
		self._range[index] = self._range[index] + value
	end
end

---1t
function _LNode.remove_bracket(lnode)
	local ntype = lnode:type()
	if string.match(ntype, "^curly_group") or ntype == "brack_group" then
		lnode = _LNode:new(lnode)
		table.remove(lnode._childrens, 1)
		table.remove(lnode._childrens)
		lnode:shift_range(0, 1, 1, 0, -1, -1)
	end
	return lnode
end

return _LNode
