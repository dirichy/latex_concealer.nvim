local M = {}
local mathfont = require("latex_concealer.filters.mathfont")
local script = require("latex_concealer.filters.script")
for k, v in pairs(mathfont) do
	M[k] = v
end
for k, v in pairs(script) do
	M[k] = v
end
return M
