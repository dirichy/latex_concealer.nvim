local extmark = require("latex_concealer.extmark")
local LNode = require("latex_concealer.lnode")
local utf8 = require("latex_concealer.utf8")
local util = require("latex_concealer.util")
local highlight = extmark.config.highlight
local counter = require("latex_concealer.counter")
local concealer = require("latex_concealer.processor.util")
local filters = require("latex_concealer.filters")
local Grid = require("latex_concealer.grid")
local subscript_tbl = require("latex_concealer.filters.script").subscript
local superscript_tbl = require("latex_concealer.filters.script").superscript
local function frac(buffer, node)
	local pss
	local arg_nodes = node:field("arg")
	if #arg_nodes ~= 2 then
		return
	end
	local up = LNode.remove_bracket(arg_nodes[1])
	local down = LNode.remove_bracket(arg_nodes[2])
	up = concealer.node2grid(buffer, up)
	down = concealer.node2grid(buffer, down)
	local super = filters.all_match(up, superscript_tbl)
	local sub = filters.all_match(down, subscript_tbl)
	if super and sub and super.height == 1 and sub.height == 1 then
		pss = {
			after = function()
				extmark.multichar_conceal(
					buffer,
					{ node = node },
					{ super.data[1][1][1] .. "/" .. sub.data[1][1][1], highlight.fraction }
				)
			end,
			grid = function(buf, n)
				return super + Grid:new({ { { "/", highlight.fraction } } }) + sub
			end,
		}
	else
		pss = concealer.delim({ "(", highlight.delim }, { ")/(", highlight.delim }, { ")", highlight.delim })
		pss.grid = function(buf, lnode)
			local arg = lnode:field("arg")
			if #arg < 2 then
				return concealer.default_grid_processor(buffer, lnode)
			end
			local arg1 = concealer.node2grid(buffer, LNode:new(arg[1]):remove_bracket())
			local arg2 = concealer.node2grid(buffer, LNode:new(arg[2]):remove_bracket())
			local w =
				math.max(arg1.width + (arg1.type == "frac" and 2 or 0), arg2.width + (arg2.type == "frac" and 2 or 0))
			local line = Grid:new({ string.rep("─", w), {} })
			local grid = arg1 - (line - arg2)
			grid.type = "frac"
			return grid
		end
	end
	return pss
end
---@param buffer integer
---@param node LNode
---@param opts table
local function overline(buffer, node, opts)
	local arg = LNode:new(node:field("arg")[1])
	if not arg then
		return
	end
	arg = concealer.node2grid(buffer, arg:remove_bracket())
	if arg.height == 1 and arg.width == 1 then
		return concealer.modify_next_char("̅", {})
	end
	local pss = concealer.delim({ "‾", highlight.delim }, { "‾", highlight.delim })
	pss.grid = function(buf, lnode)
		return Grid:new({ string.rep("_", arg.width), arg.data[1][1][2] }) - arg
	end
	return pss
end

local function tilde(buffer, node, opts)
	local arg = LNode:new(node:field("arg")[1])
	if not arg then
		return
	end
	arg = concealer.node2grid(buffer, arg:remove_bracket())
	if arg.height == 1 and arg.width == 1 then
		return concealer.modify_next_char("̃", "MathZone")
	end
	local pss = concealer.delim({ "˜", highlight.delim }, { "˜", highlight.delim })
	if arg.width == 2 then
		pss.grid = function(buf, lnode)
			return Grid:new({ "⏜𛰜", arg.data[1][1][2] }) - arg
			--𛰐--𛰛𛰜⏜⏝𛰩𛰪
		end
	elseif arg.width == 1 then
		pss.grid = function(buf, lnode)
			return Grid:new({ "˜", arg.data[1][1][2] }) - arg
		end
	else
		pss.grid = function(buf, lnode)
			local line = arg.width - 3
			local over = math.ceil(line / 2)
			local under = line - over
			return Grid:new({
				"/" .. string.rep("‾", over) .. "\\" .. string.rep("_", under) .. "/",
				arg.data[1][1][2],
			}) - arg
		end
	end
	return pss
end
---@type table<string,function|LaTeX.Processor>
return {
	["verb"] = {
		parser = function(buffer, node, opts)
			local field = opts.field
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
					if x + i < y then
						wordnode = LNode:new(nodee)
						wordnode:set_start(a, b + i, x + i)
					end
					nodee = LNode:new("char")
					nodee:set_range(a, b + i - 1, x + i - 1, a, b + i, x + i)
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
	["not"] = concealer.modify_next_char("̸", highlight.relationship, false),
	["'"] = concealer.modify_next_char("́", highlight.default, false),
	['"'] = concealer.modify_next_char("̈", highlight.default, false),
	["`"] = concealer.modify_next_char("̀", highlight.default, false),
	["="] = concealer.modify_next_char("̄", highlight.default, false),
	["~"] = concealer.modify_next_char("̃", highlight.default, false),
	["."] = concealer.modify_next_char("̇", highlight.default, false),
	["^"] = concealer.modify_next_char("̂", highlight.default, false),
	--command_delim
	["frac"] = { processor = frac, narg = 2 },
	["dfrac"] = { processor = frac, narg = 2 },
	["tfrac"] = { processor = frac, narg = 2 },
	["bar"] = overline,
	["overline"] = overline,
	["tilde"] = tilde,
	["norm"] = concealer.delim("‖", "‖"),
	["abs"] = concealer.delim("|", "|"),
	["sqrt"] = {
		oarg = true,
		narg = 2,
		processor = function(buffer, node)
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
		--   ___________
		--  ⎛
		--  ⎜
		--  ⎜
		--  ⎜
		--  ⎜
		-- √
		grid = function(buffer, node)
			local oarg = node:field("optional_arg")[1]
			local arg = node:field("arg")[1]
			arg = concealer.node2grid(buffer, LNode.remove_bracket(arg))
			local hi = arg.data[1][1][2]
			if arg.height == 1 then
				if arg.width == 1 then
					arg.data[1][1] = { "√" .. arg.data[1][1][1] .. "̅", arg.data[1][1][2] }
					arg.width = arg.width + 1
				else
					arg = Grid:new({ string.rep("_", arg.width), hi }) - arg
					arg = Grid:new({ "√", hi }) + arg
				end
			else
				arg = Grid:new({ string.rep("_", arg.width), hi }) - arg
				arg.center = math.ceil(arg.height / 2) + 1
				local data = { { { "  ", hi } }, { { " ⎛", hi } } }
				for _ = 3, arg.height - 1 do
					table.insert(data, { { " ⎜", hi } })
				end
				table.insert(data, { { "√ ", hi } })
				local sqrt = Grid:new(data)
				sqrt.center = arg.center
				arg = sqrt + arg
			end
			if oarg then
				oarg = concealer.node2grid(buffer, LNode.remove_bracket(oarg))
				if oarg.height == 1 and arg.height == 1 then
					local ss = Grid:new(oarg)
					local flag = true
					for index, value in ipairs(oarg.data[1]) do
						local s = string.gsub(value[1], ".", function(str)
							if filters.superscript[str] then
								return filters.superscript[str]
							else
								flag = false
								return str
							end
						end)
						if not flag then
							break
						end
						ss.data[1][index][1] = s
					end
					if flag then
						arg = ss + arg
						return arg
					end
				end
				oarg.center = arg.center + 1
				arg = oarg + arg
			end
			return arg
		end,
	},
	--fonts
	["mathbb"] = concealer.font(filters.mathbb, highlight.symbol),
	["mathcal"] = concealer.font(filters.mathcal, highlight.symbol),
	["mathbbm"] = concealer.font(filters.mathbbm, highlight.symbol),
	["mathfrak"] = concealer.font(filters.mathfrak, highlight.symbol),
	["mathscr"] = concealer.font(filters.mathscr, highlight.symbol),
	["mathsf"] = concealer.font(filters.mathsf, highlight.symbol),
	["operatorname"] = concealer.font(function(str)
		return str
	end, highlight.operatorname),
	["mathrm"] = concealer.font(function(str)
		return str
	end, highlight.constant),
	--other
	["footnote"] = function(buffer, node)
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
