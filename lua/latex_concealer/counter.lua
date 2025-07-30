local M = {}
local enums = { "enumi", "enumii", "enumiii", "enumiv" } --counter
local util = require("latex_concealer.util")
M.config = {
	numbering = require("latex_concealer.numbering"),
	the = {
		chapter = "\\Roman{chapter} ",
		section = "\\arabic{section} ",
		subsection = "\\arabic{section}.\\arabic{subsection} ",
		subsubsection = "\\arabic{section}.\\arabic{subsection}.\\alph{subsubsection} ",
		footnote = "\\fnsymbol{footnote}",
		enumi = "\\arabic{enumi}.",
		enumii = "(\\arabic{enumii})",
		enumiii = "\\alph{enumiii}",
		enumiv = "\\fnsymbol{enumiv}",
		error = "DON'T NEST LIST MORE THAN FOUR LAYER",
	},
	unordered = {
		"o",
		"-",
		"+",
		"=",
		"DON'T NEST LIST MORE THAN FOUR LAYER",
	},
	_counters = {
		_bracket = { value = 0 },
		enumi = { value = 0, refresh = { "enumii" } },
		enumii = { value = 0, refresh = { "enumiii" } },
		enumiii = { value = 0, refresh = { "enumiv" } },
		enumiv = { value = 0 },
		footnote = { value = 0 },
		error = { value = 0 },
		chapter = { value = 0, refresh = { "section" } },
		section = { value = 0, refresh = { "subsection" } },
		subsection = { value = 0, refresh = { "subsubsection" } },
		subsubsection = { value = 0 },
		item = {},
	},
}

M.cache = {}

function M.the(buffer, counter_name)
	if not M.config.the[counter_name] then
		M.config.the[counter_name] = "\\arabic{" .. counter_name .. "}"
	end
	local counters = M.cache[buffer].counters
	local _counters = M.cache[buffer]._counters
	if counter_name == "item" then
		counter_name = _counters.item[#_counters.item]
		if not counter_name then
			return
		end
		if type(counter_name) == "number" then
			return M.config.unordered[counter_name], counter_name
		else
			return string.gsub(M.config.the[counter_name], "\\([a-zA-Z]*){([a-zA-Z_]*)}", function(numbering, count)
				return M.config.numbering[numbering](counters[count] or 0)
			end),
				counter_name
		end
	end
	return string.gsub(M.config.the[counter_name], "\\([a-zA-Z]*){([a-zA-Z_]*)}", function(numbering, count)
		return M.config.numbering[numbering](counters[count] or 0)
	end),
		counter_name
end

function M.reset_all(buffer)
	M.cache[buffer]._counters = vim.fn.deepcopy(M.config._counters)
	M.cache[buffer].enum_depth = 0
	M.cache[buffer].item_depth = 0
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.setup_buf(buffer, opts)
	M.cache[buffer] = {
		enum_depth = 0,
		item_depth = 0,
		counters = setmetatable({}, {
			__metatable = "LaTeX_counter[]",
			__index = function(_, key)
				if key == "item" then
					return M.cache[buffer]._counters[M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]]
							and M.cache[buffer]._counters[M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]].value
						or 0
				end
				return M.cache[buffer]._counters[key] and M.cache[buffer]._counters[key].value
					or error("No counter named " .. key)
			end,
			__newindex = function(t, key, value)
				if key == "item" then
					local counter = M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]
					if type(counter) == "string" then
						t[M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]] = value
					end
					return
				end
				M.cache[buffer]._counters[key].value = value
				if M.cache[buffer]._counters[key].refresh then
					for _, counter in ipairs(M.cache[buffer]._counters[key].refresh) do
						t[counter] = 0
					end
				end
			end,
		}),
		_counters = vim.tbl_deep_extend("force", vim.fn.deepcopy(M.config._counters), opts and opts._counters or {}),
	}
end

function M.get(buffer, counter_name)
	return M.cache[buffer].counters[counter_name]
end
function M.step_counter(buffer, counter_name)
	M.cache[buffer].counters[counter_name] = M.cache[buffer].counters[counter_name] + 1
end

function M.reverse_counter(buffer, counter_name)
	M.cache[buffer].counters[counter_name] = M.cache[buffer].counters[counter_name] - 1
end

function M.step_counter_rangal(buffer, counter_name, position)
	M.step_counter(buffer, counter_name)
	util.hook(buffer, position, function(buf)
		M.reverse_counter(buf, counter_name)
	end)
end

function M.reset_counter(buffer, counter_name)
	M.cache[buffer].counters[counter_name] = 0
end

function M.item_depth_change(buffer, ordered, direct)
	local var_to_set = ordered and "enum_depth" or "item_depth"
	if direct == 1 then
		M.cache[buffer][var_to_set] = M.cache[buffer][var_to_set] + 1
		M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item + 1] = ordered
				and (enums[M.cache[buffer].enum_depth] or "error")
			or M.cache[buffer].item_depth
	elseif direct == -1 then
		if ordered then
			M.reset_counter(buffer, M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item])
		end
		M.cache[buffer][var_to_set] = M.cache[buffer][var_to_set] - 1
		M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item] = nil
	end
end

return M
