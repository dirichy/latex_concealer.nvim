local util = require("latex_concealer.util")
return {
	--Greek
	["\\alpha"] = { "α", "MathGreek" },
	["\\beta"] = { "β", "MathGreek" },
	["\\gamma"] = { "γ", "MathGreek" },
	["\\delta"] = { "δ", "MathGreek" },
	["\\epsilon"] = { "ϵ", "MathGreek" },
	["\\varepsilon"] = { "ε", "MathGreek" },
	["\\zeta"] = { "ζ", "MathGreek" },
	["\\eta"] = { "η", "MathGreek" },
	["\\theta"] = { "θ", "MathGreek" },
	["\\vartheta"] = { "ϑ", "MathGreek" },
	["\\iota"] = { "ι", "MathGreek" },
	["\\kappa"] = { "κ", "MathGreek" },
	["\\lambda"] = { "λ", "MathGreek" },
	["\\mu"] = { "μ", "MathGreek" },
	["\\nu"] = { "ν", "MathGreek" },
	["\\xi"] = { "ξ", "MathGreek" },
	["\\pi"] = { "π", "MathGreek" },
	["\\varpi"] = { "ϖ", "MathGreek" },
	["\\rho"] = { "ρ", "MathGreek" },
	["\\varrho"] = { "ϱ", "MathGreek" },
	["\\sigma"] = { "σ", "MathGreek" },
	["\\varsigma"] = { "ς", "MathGreek" },
	["\\tau"] = { "τ", "MathGreek" },
	["\\upsilon"] = { "υ", "MathGreek" },
	["\\phi"] = { "ϕ", "MathGreek" },
	["\\varphi"] = { "φ", "MathGreek" },
	["\\chi"] = { "χ", "MathGreek" },
	["\\psi"] = { "ψ", "MathGreek" },
	["\\omega"] = { "ω", "MathGreek" },
	["\\Gamma"] = { "Γ", "MathGreek" },
	["\\Delta"] = { "Δ", "MathGreek" },
	["\\Theta"] = { "Θ", "MathGreek" },
	["\\Lambda"] = { "Λ", "MathGreek" },
	["\\Xi"] = { "Ξ", "MathGreek" },
	["\\Pi"] = { "Π", "MathGreek" },
	["\\Sigma"] = { "Σ", "MathGreek" },
	["\\Upsilon"] = { "Υ", "MathGreek" },
	["\\Phi"] = { "Φ", "MathGreek" },
	["\\Chi"] = { "Χ", "MathGreek" },
	["\\Psi"] = { "Ψ", "MathGreek" },
	["\\Omega"] = { "Ω", "MathGreek" },
	--Special
	["\\exists"] = { "∃", "Special" },
	["\\forall"] = { "∀", "Special" },
	["\\mapsto"] = { "↦", "Special" },
	["\\models"] = { "╞", "Special" },
	["\\S"] = { "§", "Special" },
	["\\vdots"] = { "⋮", "Special" },
	["\\angle"] = { "∠", "Special" },
	["\\cdots"] = { "⋯", "Special" },
	["\\ddots"] = { "⋱", "Special" },
	["\\dots"] = { "…", "Special" },
	["\\ldots"] = { "…", "Special" },
	["\\natural"] = { "♮", "Special" },
	["\\flat"] = { "♭", "Special" },
	["\\sharp"] = { "♯", "Special" },
	["\\clubsuit"] = { "♣", "Special" },
	["\\diamondsuit"] = { "♢", "Special" },
	["\\heartsuit"] = { "♡", "Special" },
	["\\spadesuit"] = { "♠", "Special" },
	["\\imath"] = { "ɩ", "Special" },
	["\\jmath"] = { "𝚥", "Special" },
	["\\emptyset"] = { "∅", "Special" },
	["\\varnothing"] = { "∅", "Special" },
	["\\hbar"] = { "ℏ", "Special" },
	["\\ell"] = { "ℓ", "Special" },
	["\\infty"] = { "∞", "Special" },
	["\\aleph"] = { "ℵ", "Special" },
	["\\wp"] = { "℘", "Special" },
	["\\wr"] = { "≀", "Special" },
	["\\\\"] = { "", "Special" },
	["\\{"] = { "{", "Special" },
	["\\}"] = { "}", "Special" },
	--Operator
	["\\sin"] = { "sin", "Constant" },
	["\\cos"] = { "cos", "Constant" },
	["\\tan"] = { "tan", "Constant" },
	["\\cot"] = { "cot", "Constant" },
	["\\arcsin"] = { "arcsin", "Constant" },
	--Fraction
	["\\frac"] = function(buffer, node)
		local command_name = node:field("command")[1]
		local arg1_node, arg2_node = unpack(node:field("arg"))
		if arg1_node and arg2_node then
			local row1, col1 = command_name:range()
			local row1_end, col1_end, row2, col2 = arg1_node:range()
			local row2_end, col2_end, row3, col3 = arg2_node:range()
			util.multichar_conceal(
				buffer,
				row1,
				col1,
				row1_end,
				col1_end + 1,
				{ "(", "Special" },
				vim.api.nvim_create_namespace("latex_concealer")
			)
			util.multichar_conceal(
				buffer,
				row2,
				col2 - 1,
				row2_end,
				col2_end + 1,
				{ ")/(", "Special" },
				vim.api.nvim_create_namespace("latex_concealer")
			)
			util.multichar_conceal(
				buffer,
				row3,
				col3 - 1,
				row3,
				col3,
				{ ")", "Special" },
				vim.api.nvim_create_namespace("latex_concealer")
			)
		end
		return nil
	end,
}
