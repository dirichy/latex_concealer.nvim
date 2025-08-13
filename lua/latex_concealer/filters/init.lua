local M = {}
local mathfont = require("latex_concealer.filters.mathfont")
local script = require("latex_concealer.filters.script")
local utf8 = require("latex_concealer.utf8")
local Grid = require("latex_concealer.grid")
for k, v in pairs(mathfont) do
	M[k] = v
end
for k, v in pairs(script) do
	M[k] = v
end
--- try to gsub all unicode char in str by filter, if success then return the reslut, else return false
---@param str string
---@param filter table<string,string>
---@return string
---@overload fun(str:Grid,filter):Grid
function M.all_match(str, filter)
	local flag = true
	if type(str) == "string" then
		str = string.gsub(str, utf8.patten, function(s)
			if not flag then
				return s
			end
			if filter[s] then
				return filter[s]
			else
				flag = false
				return s
			end
		end)
		return flag and str
	else
		local ss = Grid:new(str)
		for index, line in ipairs(str.data) do
			if not flag then
				break
			end
			for jndex, atom in ipairs(line) do
				if not flag then
					break
				end
				ss.data[index][jndex][1] = string.gsub(atom[1], utf8.patten, function(s)
					if not flag then
						return s
					end
					if filter[s] then
						return filter[s]
					else
						flag = false
						return s
					end
				end)
			end
		end
		return flag and ss
	end
end
return M
