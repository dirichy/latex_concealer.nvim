local M = {}
local util = require("latex_concealer.util")
M.config = {
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
	icon_formatter = {
		numbering = {
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
			Roman = function(index)
				if index <= 0 or index > 3999 then
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
		},
		heading = {
			chapter = { "\\zhdig{chapter}、", "ErrorMsg" },
			section = { "\\arabic{section}", "Constant" },
			subsection = { "\\arabic{subsection}", "DiagnosticHint" },
			subsubsection = { "\\alph{subsubsection}", "SpecialKey" },
		},
	},
}
return M
