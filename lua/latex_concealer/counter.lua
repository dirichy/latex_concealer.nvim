local M = {}
local enums = { "enumi", "enumii", "enumiii", "enumiv" } --counter

M.config = {
	numbering = require("latex_concealer.numbering"),
	the = {
		chapter = { "\\Roman{chapter} ", "ErrorMsg" },
		section = { "\\arabic{section} ", "Constant" },
		subsection = { "\\arabic{section}.\\arabic{subsection} ", "DiagnosticHint" },
		subsubsection = {
			"\\arabic{section}.\\arabic{subsection}.\\alph{subsubsection} ",
			"Special",
		},
		footnote = { "\\fnsymbol{footnote}", "Special" },
		enumi = { "\\arabic{enumi}.", "ErrorMsg" },
		enumii = { "(\\arabic{enumii})", "Constant" },
		enumiii = { "\\alph{enumiii}", "DiagnosticHint" },
		enumiv = { "\\fnsymbol{enumiv}", "Special" },
		error = { "DON'T NEST LIST MORE THAN FOUR LAYER", "ErrorMsg" },
	},
	unordered = {
		{ "o", "ErrorMsg" },
		{ "-", "Constant" },
		{ "+", "DiagnosticHint" },
		{ "=", "Special" },
		{ "DON'T NEST LIST MORE THAN FOUR LAYER", "ErrorMsg" },
	},
	_counters = {
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
	local counters = M.cache[buffer].counters
	local _counters = M.cache[buffer]._counters
	if counter_name == "item" then --counter
		counter_name = _counters.item[#_counters.item] --counter
		if not counter_name then
			return
		end
		if type(counter_name) == "number" then --counter
			return M.config.unordered[counter_name] --counter
		else --counter
			return { --counter
				string.gsub( --counter
					M.config.the[counter_name][1], --counter
					"\\([a-zA-Z]*){([a-zA-Z]*)}", --counter
					function(numbering, count) --counter
						return M.config.numbering[numbering](counters[count] or 0) --counter
					end --counter
				), --counter
				M.config.the[counter_name][2], --counter
			} --counter
		end --counter
	end --counter
	return { --counter
		string.gsub( --counter
			M.config.the[counter_name][1], --counter
			"\\([a-zA-Z]*){([a-zA-Z]*)}", --counter
			function(numbering, count) --counter
				return M.config.numbering[numbering](counters[count] or 0) --counter
			end --counter
		),
		M.config.the[counter_name][2], --counter
	} --counter
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
		counters = setmetatable({}, { --counter
			__metatable = "LaTeX_counter[]", --counter
			__index = function(_, key) --counter
				if key == "item" then --counter
					return M.cache[buffer]._counters[M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]] --counter
							and M.cache[buffer]._counters[M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]].value --counter
						or 0 --counter
				end --counter
				return M.cache[buffer]._counters[key] and M.cache[buffer]._counters[key].value
					or error("No counter named " .. key) --counter
			end, --counter
			__newindex = function(t, key, value) --counter
				if key == "item" then --counter
					local counter = M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item] --counter
					if type(counter) == "string" then --counter
						t[M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item]] = value --counter
					end --counter
					return --counter
				end --counter
				M.cache[buffer]._counters[key].value = value --counter
				if M.cache[buffer]._counters[key].refresh then --counter
					for _, counter in ipairs(M.cache[buffer]._counters[key].refresh) do --counter
						t[counter] = 0 --counter
					end --counter
				end --counter
			end, --counter
		}), --counter
		_counters = vim.tbl_deep_extend("force", vim.fn.deepcopy(M.config._counters), opts and opts._counters or {}),
	}
end

function M.step_counter(buffer, counter_name)
	M.cache[buffer].counters[counter_name] = M.cache[buffer].counters[counter_name] + 1
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
