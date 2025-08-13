local ffi = require("ffi")

ffi.cdef([[
    int setlocale(int category, const char *locale);
    int wcwidth(int c);
]])

-- 设定本地化（重要，否则 wcwidth 对 CJK 宽度可能不准）
ffi.C.setlocale(0, "")

-- 单个 UTF-8 字符转 Unicode 码点
---@param s string
---@param i integer
---@return integer?,integer?
local function utf8_codepoint_at(s, i)
	local b1 = string.byte(s, i)
	if not b1 then
		return nil
	end
	if b1 < 0x80 then
		return b1, i + 1
	elseif b1 < 0xE0 then
		local b2 = string.byte(s, i + 1)
		return (b1 - 0xC0) * 0x40 + (b2 - 0x80), i + 2
	elseif b1 < 0xF0 then
		local b2, b3 = string.byte(s, i + 1, i + 2)
		return (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80), i + 3
	else
		local b2, b3, b4 = string.byte(s, i + 1, i + 3)
		return (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80), i + 4
	end
end

-- 计算字符串宽度
local function utf8_strwidth(s)
	local width = 0
	local i = 1
	while i <= #s do
		local cp
		cp, i = utf8_codepoint_at(s, i)
		if not cp then
			break
		end
		local w = ffi.C.wcwidth(cp)
		if w > 0 then
			width = width + w
		end
	end
	return width
end

local function utf8_len(s)
	local len = 0
	local i = 1
	while i <= #s do
		local cp
		cp, i = utf8_codepoint_at(s, i)
		if not cp then
			break
		end
		len = len + 1
	end
	return len
end
---@param s string
---@return Iter<string>
local function utf8_iter_char(s)
	local i = 1
	return function()
		if i <= #s then
			local cp
			local j = i
			cp, i = utf8_codepoint_at(s, i)
			if cp then
				return string.sub(s, j, i)
			end
		end
		return nil
	end
end

return { width = utf8_strwidth, len = utf8_len, iter_char = utf8_iter_char, patten = "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*" }
