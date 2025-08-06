---@class LaTeX.Processor
---@field init (fun(buffer:integer,node:LNode):LaTeX.Processor?)?
---@field parser (fun(buffer:integer,node:LNode,field:string):LaTeX.Parser?)? You can make your own parser here for some node like `\verb'.
---@field oarg boolean? I have made a parser for optional arg and arg whih no curly brackets, set oarg to true will try to parser an optional arg with `[]`
---@field narg integer? set `narg` to a number to define the number of args, optional includes. If `narg` is nil, the parser will only try to find args with curly brackets.
---@field before ( fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil )? will be called before all children of `node` are processed
---@field after (fun(buffer:integer,node:LNode):LaTeX.Processor|function|nil)? will be called after all children of `node` are processed

local extmark = require("latex_concealer.extmark")
local LNode = require("latex_concealer.lnode")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
local concealer = require("latex_concealer.processor.util")
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
	local up = vim.treesitter.get_node_text(arg_nodes[1], buffer)
	if #up > 1 then
		up = up:sub(2, -2)
	end
	local down = vim.treesitter.get_node_text(arg_nodes[2], buffer)
	if #down > 1 then
		down = down:sub(2, -2)
	end
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
	["\\verb"] = {
		parser = function(buffer, node, field)
			local lnode = LNode:new("generic_command")
			lnode:add_child(node:field("command")[1], "command")
			lnode:set_range(node)
			local arg_node = LNode:new("verb_group")
			local open = nil
			---@param nodee LNode?
			---@param fieldd string
			---@return LNode|LNode[]|nil if return nil, then this node is not finished, so we need to continue parse.
			---If return Lnode or LNode[], then this node is finished.
			return function(nodee, fieldd)
				if not nodee then
					return { { lnode, field } }
				end
				if not open then
					if nodee:type() == "word" then
						nodee = LNode:new(nodee)
						nodee._type = "char"
						local a, b, x = nodee:start()
						nodee:set_end(a, b + 1, x + 1)
					end
					open = vim.treesitter.get_node_text(nodee, buffer)
					if #open > 1 then
						return { { nodee, fieldd }, { lnode, field } }
					end
					arg_node:add_child(nodee, "open")
					arg_node:set_start(nodee)
					lnode:add_child(arg_node, "arg")
					return
				end
				local i = string.find(vim.treesitter.get_node_text(nodee, buffer), open, nil, true)
				local wordnode
				if nodee:type() == "word" and i then
					local a, b, x, c, d, y = nodee:range(true)
					print(a, b, x, c, d, y)
					nodee = LNode:new("char")
					nodee:set_range(a, b + i - 1, x + i - 1, a, b + i, x + i)
					if x + i < y then
						wordnode = LNode:new(nodee)
						wordnode:set_start(a, b + i, x + i)
					end
				end
				if open == vim.treesitter.get_node_text(nodee, buffer) then
					arg_node:add_child(nodee, "close")
					arg_node:set_end(nodee)
					lnode:set_end(nodee)
					local a, b, x = arg_node:start()
					local c, d, y = arg_node:end_()
					local verb_inner = LNode:new("verb_inner")
					verb_inner:set_range(a, b + 1, x + 1, c, d - 1, y - 1)
					if wordnode then
						return { { wordnode, fieldd }, { lnode, field } }
					end
					return { { lnode, field } }
				end
			end
		end,
	},
	["\\not"] = concealer.modify_next_char("̸", highlight.relationship, false),
	["\\'"] = concealer.modify_next_char("́", highlight.default, false),
	['\\"'] = concealer.modify_next_char("̈", highlight.default, false),
	["\\`"] = concealer.modify_next_char("̀", highlight.default, false),
	["\\="] = concealer.modify_next_char("̄", highlight.default, false),
	["\\~"] = concealer.modify_next_char("̃", highlight.default, false),
	["\\."] = concealer.modify_next_char("̇", highlight.default, false),
	["\\^"] = concealer.modify_next_char("̂", highlight.default, false),
	--command_delim
	["\\frac"] = { init = frac, narg = 2 },
	["\\dfrac"] = { init = frac, narg = 2 },
	["\\tfrac"] = { init = frac, narg = 2 },
	["\\bar"] = overline,
	["\\overline"] = overline,
	["\\tilde"] = tilde,
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
