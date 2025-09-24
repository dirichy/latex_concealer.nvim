---@class Grid.atom
---@field [1] string
---@field [2] string|string[]
---@alias Grid.line Grid.atom[]
---@alias Grid.lines Grid.line[]
---@class Grid
---@field center integer
---@field node LNode?
---@field type string?
---@field width integer
---@field height integer
---@field data Grid.lines
local Grid = {}
Grid.__index = Grid
local check = true
local utf8 = require("latex_concealer.utf8")
local function get_length(data)
	if not data then
		return 0
	end
	local length = 0
	for _, value in ipairs(data) do
		length = length + utf8.width(value[1])
	end
	return length
end

-- local LNode = require("latex_concealer.lnode")
-- local parser = require("latex_concealer.parser")
-- local processor = require("latex_concealer.processor")

--- a
---@param buffer number
---@param node LNode
---@return Grid

---@param data string|Grid.atom|Grid.line|Grid.lines|nil|Grid|number
---@param lnode LNode?
---@return Grid
---@overload fun(number:integer,lnode:LNode):Grid
function Grid:new(data)
	if not data then
		data = { {} }
	end
	if type(data) == "string" then
		data = { { { data, "Normal" } } }
	end
	if data.data then
		return setmetatable(vim.deepcopy(data), Grid)
	end
	if type(data[1]) == "string" then
		data = { { data } }
	end
	if data[1] and type(data[1][1]) == "string" then
		data = { data }
	end
	local grid = { data = data }
	grid.height = #data
	grid.width = get_length(data[1])
	if check then
		for _, value in pairs(data) do
			if get_length(value) ~= grid.width then
				error("width of lines are not equal.")
			end
		end
	end
	grid.center = math.floor((#data + 1) / 2)
	setmetatable(grid, Grid)
	return grid
end

function Grid:show()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = 5,
		col = 10,
		width = self.width,
		height = self.height + 1,
		style = "minimal",
		border = "rounded",
	})
	-- local virt_lines = {}
	-- for i = #self.data - self.height + 1, #self.data do
	-- 	virt_lines[i + self.height - #self.data] = self.data[i]
	-- end
	vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("latex_concealer"), 0, 0, {
		virt_lines = self.data,
	})
	vim.keymap.set("n", "q", ":q<cr>", { buffer = buf, remap = false })
end

function Grid:line(n)
	return self.data[self.center + n] or { { string.rep(" ", self.width), {} } }
end

---@param top integer
---@param bottom integer?
---@return Grid
---@overload fun(top:integer,bottom:nil):Grid when bottom is nil, will split top into top and bottom equally.
function Grid:add_blank_line(top, bottom)
	if not top then
		return self
	end
	if not bottom then
		bottom = math.floor(top / 2)
		top = top - bottom
	end
	local blank = self.width > 0 and { { string.rep(" ", self.width), {} } } or {}
	for _ = 1, top do
		table.insert(self.data, 1, vim.deepcopy(blank))
	end
	for _ = 1, bottom do
		table.insert(self.data, vim.deepcopy(blank))
	end
	self.height = top + bottom + self.height
	self.center = top + self.center
	return self
end

---@param right integer
---@param left integer?
---@return Grid
---@overload fun(right:integer,left:nil):Grid when left is nil, will split right into right and left equally.
function Grid:add_blank_col(right, left)
	if not right then
		return self
	end
	if not left then
		left = math.floor(right / 2)
		right = right - left
	end
	if right + left == 0 then
		return self
	end
	for _, value in pairs(self.data) do
		if left > 0 then
			table.insert(value, 1, { string.rep(" ", left), {} })
		end
		if right > 0 then
			table.insert(value, { string.rep(" ", right), {} })
		end
	end
	self.width = self.width + left + right
	return self
end
--- add two grid
---@param a Grid
---@param b Grid
---@return Grid
function Grid.__add(a, b)
	local c = Grid:new(a)
	c.type = b.type
	if a.type == "frac" and b.type == "frac" then
		c:add_blank_col(1, 0)
	end
	if a.center < b.center then
		c:add_blank_line(b.center - a.center, 0)
	end
	local min = math.min(-a.center, -b.center) + 1
	local max = math.max(a.height - a.center, b.height - b.center)
	for i = min, max do
		c.data[i + c.center] = c.data[i + c.center] or c:line(i)
		for _, v in ipairs(b:line(i)) do
			table.insert(c:line(i), v)
		end
	end
	c.width = c.width + b.width
	c.height = max - min + 1
	return c
end

function Grid.__sub(a, b)
	local c = Grid:new(a)
	local d = Grid:new(b)
	local diff = c.width - d.width
	if diff > 0 then
		d:add_blank_col(diff)
	elseif diff < 0 then
		c:add_blank_col(-diff)
	end
	c.type = nil
	for _, value in ipairs(d.data) do
		table.insert(c.data, value)
	end
	c.center = c.height + 1
	c.height = c.height + b.height
	return c
end

function Grid.__pow(a, b)
	local c = Grid:new(a)
	local d = Grid:new(b)
	d.type = nil
	local w = c.width
	c:add_blank_col(d.width, 0)
	d:add_blank_col(0, w)
	for _, value in ipairs(c.data) do
		table.insert(d.data, value)
	end
	d.center = d.height + c.center
	d.height = c.height + d.height
	return d
end

function Grid.__mod(a, b)
	local c = Grid:new(a)
	local d = Grid:new(b)
	d.type = nil
	local w = c.width
	c:add_blank_col(d.width, 0)
	d:add_blank_col(0, w)
	for _, value in ipairs(d.data) do
		table.insert(c.data, value)
	end
	c.height = c.height + d.height
	return c
end

return Grid
