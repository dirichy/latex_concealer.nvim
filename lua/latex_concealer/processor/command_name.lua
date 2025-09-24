local highlight = require("latex_concealer.extmark").config.highlight
local M = {}
for key, value in pairs(require("nvimtex.symbol.items")) do
	if type(value.conceal) == "string" then
		M[key] = { value.conceal, highlight[value.class] }
	end
end
return M
