local M = {}
local enums = { "enumi", "enumii", "enumiii", "enumiv" } --counter

M.config = {
	numbering = require("latex_concealer.numbering"),
	the = {
		chapter = { "\\zhnum{chapter}、", "ErrorMsg" },
		section = { "\\Roman{chapter}.\\roman{section} ", "Constant" },
		subsection = { "\\arabic{chapter}.\\arabic{section}.\\arabic{subsection} ", "DiagnosticHint" },
		subsubsection = {
			"\\arabic{chapter}.\\arabic{section}.\\arabic{subsection}\\alph{subsubsection} ",
			"Special",
		},
		enumi = { "\\zhdig{section}.\\Roman{enumi}.", "ErrorMsg" },
		enumii = { "\\Roman{enumi}.\\Alph{enumii}", "Constant" },
		enumiii = { "\\Roman{enumi}.\\Alph{enumii}(\\zhdig{enumiii})", "DiagnosticHint" },
		enumiv = { "\\fnsymbol{enumiv}", "SpecialKey" },
	},
	unordered = {
		{ "o", "ErrorMsg" },
		{ "-", "Constant" },
		{ "+", "DiagnosticHint" },
		{ "=", "SpecialKey" },
	},
	_counters = {
		enumi = { value = 0, refresh = { "enumii" } },
		enumii = { value = 0, refresh = { "enumiii" } },
		enumiii = { value = 0, refresh = { "enumiv" } },
		enumiv = { value = 0 },
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
	if counter_name == "item" then --counter
		counter_name = counters.item[#counters.item] --counter
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
		), --counter
		M.config.the[counter_name][2], --counter
	} --counter
end

function M.reset_all(buffer)
	M.cache[buffer]._counters = vim.fn.deepcopy(M.config._counters)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts)
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
						or nil --counter
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
		_counters = vim.tbl_deep_extend("force", vim.fn.deepcopy(M.config._counters), opts._counters),
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
				and enums[M.cache[buffer].enum_depth]
			or M.cache[buffer].item_depth
	elseif direct == -1 then
		if ordered then
			M.reset_counter(buffer, "item")
		end
		M.cache[buffer][var_to_set] = M.cache[buffer][var_to_set] - 1
		M.cache[buffer]._counters.item[#M.cache[buffer]._counters.item] = nil
	end
end

return M
