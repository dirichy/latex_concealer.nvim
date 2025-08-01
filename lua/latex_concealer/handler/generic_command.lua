---@class LaTeX.Processor
---@field oarg boolean?
---@field narg integer?
---@field init ( fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil )?
---@field before ( fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil )?
---@field after (fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil)?

local extmark = require("latex_concealer.extmark")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
local concealer = require("latex_concealer.handler.util")
local filters = require("latex_concealer.filters")
local subscript_tbl = {
	["-"] = "₋",
	["0"] = "₀",
	["1"] = "₁",
	["2"] = "₂",
	["3"] = "₃",
	["4"] = "₄",
	["5"] = "₅",
	["6"] = "₆",
	["7"] = "₇",
	["8"] = "₈",
	["9"] = "₉",
}
local superscript_tbl = {
	["-"] = "⁻",
	["0"] = "⁰",
	["1"] = "¹",
	["2"] = "²",
	["3"] = "³",
	["4"] = "⁴",
	["5"] = "⁵",
	["6"] = "⁶",
	["7"] = "⁷",
	["8"] = "⁸",
	["9"] = "⁹",
}
local function frac(buffer, node)
	local arg_nodes = node:field("arg")
	if #arg_nodes ~= 2 then
		return
	end
	local up = vim.treesitter.get_node_text(arg_nodes[1], buffer):sub(2, -2)
	local down = vim.treesitter.get_node_text(arg_nodes[2], buffer):sub(2, -2)
	if string.match(up .. down, "^[-]?[0-9-]*$") then
		up = up:gsub(".", superscript_tbl)
		down = down:gsub(".", subscript_tbl)
		extmark.multichar_conceal(buffer, { node = node }, { up .. "/" .. down, highlight.fraction })
		return
	end
	return concealer.delim({ "(", highlight.delim }, { ")/(", highlight.delim }, { ")", highlight.delim })
end
local function overline(buffer, node, opts)
	if not node:field("arg") or not node:field("arg")[1] then
		return
	end
	local text = vim.treesitter.get_node_text(node:field("arg")[1], buffer):sub(2, -2)
	if string.match(text, "^[a-zA-Z]$") then
		extmark.multichar_conceal(buffer, { node = node }, { text .. "̅", "MathZone" })
		return
	else
		return concealer.delim({ "‾", highlight.delim }, { "‾", highlight.delim })
	end
end

local function tilde(buffer, node, opts)
	if not node:field("arg") or not node:field("arg")[1] then
		return
	end
	local text = vim.treesitter.get_node_text(node:field("arg")[1], buffer):sub(2, -2)
	if string.match(text, "^[a-zA-Z]$") then
		extmark.multichar_conceal(buffer, { node = node }, { text .. "̃", "MathZone" })
		return
	else
		return concealer.delim({ "˜", highlight.delim }, { "˜", highlight.delim })
	end
end
---@type table<string,function|LaTeX.Processor>
return {
	["\\not"] = concealer.modify_next_char("̸", highlight.relationship, false),
	["\\'"] = concealer.modify_next_char("́", highlight.default, false),
	['\\"'] = concealer.modify_next_char("̈", highlight.default, false),
	["\\`"] = concealer.modify_next_char("̀", highlight.default, false),
	["\\="] = concealer.modify_next_char("̄", highlight.default, false),
	["\\~"] = concealer.modify_next_char("̃", highlight.default, false),
	["\\."] = concealer.modify_next_char("̇", highlight.default, false),
	["\\^"] = concealer.modify_next_char("̂", highlight.default, false),
	--command_delim
	["\\frac"] = { init = frac },
	["\\dfrac"] = { init = frac },
	["\\tfrac"] = { init = frac },
	["\\bar"] = { init = overline },
	["\\overline"] = { init = overline },
	["\\tilde"] = { init = tilde },
	["\\norm"] = concealer.delim("‖", "‖"),
	["\\abs"] = concealer.delim("|", "|"),
	["\\sqrt"] = {
		oarg = true,
		narg = 2,
		init = function(buffer, node)
			local optional_arg = node:field("optional_arg")[1]
			if optional_arg then
				local up_number = vim.treesitter.get_node_text(optional_arg, buffer):sub(2, -2)
				if up_number:match("^[-]?[0-9-]*$") then
					up_number = string.gsub(up_number, ".", superscript_tbl)
					return concealer.delim(up_number .. "√(", ")", false)
				end
				return concealer.delim({ "(", highlight.delim }, { ")√(", highlight.delim }, { ")", highlight.delim })
			else
				return concealer.delim({ "√(", highlight.delim }, { ")", highlight.delim })
			end
		end,
	},
	--fonts
	["\\mathbb"] = concealer.font(filters.mathbb, highlight.symbol),
	["\\mathcal"] = concealer.font(filters.mathcal, highlight.symbol),
	["\\mathbbm"] = concealer.font(filters.mathbbm, highlight.symbol),
	["\\mathfrak"] = concealer.font(filters.mathfrak, highlight.symbol),
	["\\mathscr"] = concealer.font(filters.mathscr, highlight.symbol),
	["\\mathsf"] = concealer.font(filters.mathsf, highlight.symbol),
	["\\operatorname"] = concealer.font(function(str)
		return str
	end, highlight.operatorname),
	["\\mathrm"] = concealer.font(function(str)
		return str
	end, highlight.constant),
	--other
	["\\footnote"] = function(buffer, node)
		counter.step_counter(buffer, "footnote")
		local arg_nodes = node:field("arg")
		if #arg_nodes < 2 then
			return
		end
		local a, b = node:range()
		local _, _, c, d = arg_nodes[1]:range()
		d = d + 1
		extmark.multichar_conceal(buffer, { a, b, c, d }, { counter.the(buffer, "footnote"), highlight.footnotemark })
		_, _, a, b = arg_nodes[2]:range()
		extmark.multichar_conceal(buffer, { a, b - 1, a, b }, "")
	end,
}
