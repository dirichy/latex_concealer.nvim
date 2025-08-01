---@alias LNode _LNode|TSNode
---@class _LNode
-- -@field _parent _LNode?
-- -@field _index number?
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
	return self._field[name]
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
	return self._childrens[index]
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

--- Check if {node} refers to the same node within the same tree.
--- @param node _LNode
--- @return boolean
function _LNode:equal(node)
	return self == node
end
function _LNode:new()
	return setmetatable({}, _LNode)
end

return _LNode
