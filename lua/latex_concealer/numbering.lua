return {
	Alph = function(index)
		if index > 0 and index < 27 then
			return string.char(string.byte("A") + index - 1)
		else
			return "Alph should in 1-26"
		end
	end,
	alph = function(index)
		if index > 0 and index < 27 then
			return string.char(string.byte("a") + index - 1)
		else
			return "alph should in 1-26"
		end
	end,
	arabic = tostring,
	fnsymbol = function(index)
		local fnsymbol_table = { "∗", "†", "‡", "§", "¶", "‖", "∗∗", "††", "‡‡" }
		return fnsymbol_table[index] or "fnsymbol should in 1-9"
	end,
	zhdig = function(index)
		if index <= 0 then
			return "zhdig should in 1-\\infty"
		end
		local zhdigs = { "一", "二", "三", "四", "五", "六", "七", "八", "九", "〇" }
		local digit
		local result = ""
		while index ~= 0 do
			digit = index % 10
			index = (index - digit) / 10
			if digit == 0 then
				result = zhdigs[10] .. result
			else
				result = zhdigs[digit] .. result
			end
		end
		return result
	end,
	zhnum = function(num)
		local units1 = { "", "十", "百", "千" } -- 个、十、百、千
		local units2 = { "", "万", "亿" } -- 万、亿
		local digits = { "零", "一", "二", "三", "四", "五", "六", "七", "八", "九" }
		local result = ""
		local segments = {}

		-- 将数字按万和亿分段
		while num > 0 do
			table.insert(segments, num % 10000)
			num = math.floor(num / 10000)
		end

		-- 处理每个分段
		for i, segment in ipairs(segments) do
			local segmentStr = ""
			if segment == 0 then
				segmentStr = digits[1]
			end
			if segment > 0 then
				local zeroFlag = false
				local endFlag = true
				for j = 1, 4 do
					local digit = segment % 10
					segment = math.floor(segment / 10)
					if digit ~= 0 then
						if zeroFlag and not endFlag then
							segmentStr = digits[1] .. segmentStr
						end
						segmentStr = digits[digit + 1] .. units1[j] .. segmentStr
						zeroFlag = false
						endFlag = false
					else
						zeroFlag = true
					end
				end
				if zeroFlag then
					segmentStr = digits[1] .. segmentStr
				end

				-- 添加万或亿单位
				if i > 1 then
					segmentStr = segmentStr .. units2[i]
				end
			end
			result = segmentStr .. result
		end
		return result:gsub("^零", ""):gsub("零$", ""):gsub("^一十", "十")
	end,
	Roman = function(index)
		if index <= 0 or index > 3999 then
			print(index)
			return "Roman should in 1-3999"
		end
		local roman_table = { { "I", "V" }, { "X", "L" }, { "C", "D" }, { "M" } }
		local digit
		local result = ""
		local pos = 0
		while index ~= 0 do
			pos = pos + 1
			digit = index % 10
			index = (index - digit) / 10
			if digit < 4 then
				result = string.rep(roman_table[pos][1], digit) .. result
			elseif digit == 4 then
				result = roman_table[pos][1] .. roman_table[pos][2] .. result
			else
				result = roman_table[pos][2] .. string.rep(roman_table[pos][1], digit - 5) .. result
			end
		end
		return result
	end,
	roman = function(index)
		if index <= 0 or index > 3999 then
			return "roman should in 1-3999"
		end
		local roman_table = { { "i", "v" }, { "x", "l" }, { "c", "d" }, { "m" } }
		local digit
		local result = ""
		local pos = 0
		while index ~= 0 do
			pos = pos + 1
			digit = index % 10
			index = (index - digit) / 10
			if digit < 4 then
				result = string.rep(roman_table[pos][1], digit) .. result
			elseif digit == 4 then
				result = roman_table[pos][1] .. roman_table[pos][2] .. result
			else
				result = roman_table[pos][2] .. string.rep(roman_table[pos][1], digit - 5) .. result
			end
		end
		return result
	end,
}
