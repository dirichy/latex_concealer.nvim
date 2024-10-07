local util = require("latex_concealer.util")
local concealer = require("latex_concealer.handler.util").conceal
local filters = require("latex_concealer.filters")
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
	--debackslash
	["\\sin"] = { "sin", "Constant" },
	["\\cos"] = { "cos", "Constant" },
	["\\tan"] = { "tan", "Constant" },
	["\\cot"] = { "cot", "Constant" },
	["\\arcsin"] = { "arcsin", "Constant" },
	--Operator
	["\\approx"] = { "≈", "Operator" }, --op
	["\\cap"] = { "∩", "Operator" }, --op
	["\\cdot"] = { "·", "Operator" }, --op
	["\\circ"] = { "∘", "Operator" }, --op
	["\\cup"] = { "∪", "Operator" }, --op
	["\\div"] = { "÷", "Operator" }, --op
	["\\land"] = { "∧", "Operator" }, --op
	["\\lor"] = { "∨", "Operator" }, --op
	["\\mp"] = { "∓", "Operator" }, --op
	["\\nabla"] = { "∇", "Operator" }, --op
	["\\neg"] = { "¬", "Operator" }, --op
	["\\odot"] = { "⊙", "Operator" }, --op
	["\\ominus"] = { "⊖", "Operator" }, --op
	["\\oplus"] = { "⊕", "Operator" }, --op
	["\\oslash"] = { "⊘", "Operator" }, --op
	["\\otimes"] = { "⊗", "Operator" }, --op
	["\\partial"] = { "∂", "Operator" }, --op
	["\\pm"] = { "±", "Operator" }, --op
	["\\Re"] = { "ℜ", "Operator" }, --op
	["\\Im"] = { "ℑ", "Operator" },
	["\\setminus"] = { "∖", "Operator" }, --op
	["\\sqcap"] = { "⊓", "Operator" }, --op
	["\\sqcup"] = { "⊔", "Operator" }, --op
	["\\times"] = { "×", "Operator" }, --op
	["\\triangle"] = { "∆", "Operator" }, --op
	["\\vee"] = { "∨", "Operator" }, --op
	["\\wedge"] = { "∧", "Operator" }, --op
	["\\amalg"] = { "∐", "Operator" },
	["\\coprod"] = { "∐", "Operator" },
	["\\rceil"] = { "⌉", "Operator" },
	["\\asymp"] = { "≍", "Operator" },
	["\\lceil"] = { "⌈", "Operator" },
	["\\lfloor"] = { "⌊", "Operator" },
	["\\rfloor"] = { "⌋", "Operator" },
	["\\rightleftharpoons"] = { "⇌", "Operator" },
	--Huge Operator
	["\\bigcap"] = { "∩", "Operator" },
	["\\bigcirc"] = { "○", "Operator" },
	["\\bigcup"] = { "∪", "Operator" },
	["\\bigodot"] = { "⊙", "Operator" },
	["\\bigoplus"] = { "⊕", "Operator" },
	["\\bigotimes"] = { "⊗", "Operator" },
	["\\bigsqcup"] = { "⊔", "Operator" },
	["\\bigtriangledown"] = { "∇", "Operator" },
	["\\bigtriangleup"] = { "∆", "Operator" },
	["\\bigvee"] = { "⋁", "Operator" },
	["\\bigwedge"] = { "⋀", "Operator" },
	["\\int"] = { "∫", "Operator" }, --bop
	["\\oint"] = { "∮", "Operator" }, --bop
	["\\prod"] = { "∏", "Operator" }, --bop
	["\\sum"] = { "∑", "Operator" }, --bop
	--arrows
	["\\mapsto"] = { "↦", "Function" },
	["\\Downarrow"] = { "⇓", "Function" },
	["\\nearrow"] = { "↗", "Function" },
	["\\nwarrow"] = { "↖", "Function" },
	["\\searrow"] = { "↘", "Function" },
	["\\swarrow"] = { "↙", "Function" },
	["\\Uparrow"] = { "⇑", "Function" },
	["\\updownarrow"] = { "↕", "Function" },
	["\\Updownarrow"] = { "⇕", "Function" },
	["\\to"] = { "→", "Function" }, --re
	["\\uparrow"] = { "↑", "Function" }, --re
	["\\rightarrow"] = { "→", "Function" }, --re
	["\\Rightarrow"] = { "⇒", "Function" }, --re
	["\\leftarrow"] = { "←", "Function" }, --re
	["\\Leftarrow"] = { "⇐", "Function" }, --re
	["\\leftharpoondown"] = { "↽", "Function" }, --re
	["\\leftharpoonup"] = { "↼", "Function" }, --re
	["\\leftrightarrow"] = { "↔", "Function" }, --re
	["\\Leftrightarrow"] = { "⇔", "Function" }, --re
	["\\gets"] = { "←", "Function" }, --re
	["\\iff"] = { "⇔", "Function" }, --re
	["\\downarrow"] = { "↓", "Function" }, --re
	--relationship
	["\\bot"] = { "⊥", "Statement" }, --re
	["\\cong"] = { "≅", "Statement" }, --re
	["\\doteq"] = { "≐", "Statement" }, --re
	["\\equiv"] = { "≡", "Statement" }, --re
	["\\ge"] = { "≥", "Statement" }, --re
	["\\geq"] = { "≥", "Statement" }, --re
	["\\in"] = { "∈", "Statement" }, --re
	["\\le"] = { "≤", "Statement" }, --re
	["\\leq"] = { "≤", "Statement" }, --re
	["\\ll"] = { "≪", "Statement" }, --re
	["\\mid"] = { "∣", "Statement" }, --re
	["\\ne"] = { "≠", "Statement" }, --re
	["\\neq"] = { "≠", "Statement" }, --re
	["\\ni"] = { "∋", "Statement" }, --re
	["\\nmid"] = { "∤", "Statement" },
	["\\notin"] = { "∉", "Statement" }, --re
	["\\owns"] = { "∋", "Statement" }, --re
	["\\parallel"] = { "║", "Statement" }, --re
	["\\perp"] = { "⊥", "Statement" }, --re
	["\\prec"] = { "≺", "Statement" }, --re
	["\\preceq"] = { "⪯", "Statement" }, --re
	["\\propto"] = { "∝", "Statement" }, --re
	["\\sim"] = { "∼", "Statement" }, --re
	["\\simeq"] = { "⋍", "Statement" }, --re
	["\\sqsubset"] = { "⊏", "Statement" }, --re
	["\\sqsubseteq"] = { "⊑", "Statement" }, --re
	["\\sqsupset"] = { "⊐", "Statement" }, --re
	["\\sqsupseteq"] = { "⊒", "Statement" }, --re
	["\\subset"] = { "⊂", "Statement" }, --re
	["\\subseteq"] = { "⊆", "Statement" }, --re
	["\\succ"] = { "≻", "Statement" }, --re
	["\\succeq"] = { "⪰", "Statement" }, --re
	["\\supset"] = { "⊃", "Statement" }, --re
	["\\supseteq"] = { "⊇", "Statement" }, --re
	["\\vdash"] = { "⊢", "Statement" }, --re
	--others
	["\\|"] = { "‖", "Identifier" },
	["\\ast"] = { "∗", "Identifier" },
	["\\backslash"] = { "∖", "Identifier" },
	["\\bowtie"] = { "⋈", "Identifier" },
	["\\bullet"] = { "•", "Identifier" },
	["\\copyright"] = { "©", "Identifier" },
	["\\dagger"] = { "†", "Identifier" },
	["\\dashv"] = { "⊣", "Identifier" },
	["\\ddagger"] = { "‡", "Identifier" },
	["\\diamond"] = { "⋄", "Identifier" },
	["\\frown"] = { "⁔", "Identifier" },
	["\\gg"] = { "⟫", "Identifier" },
	["\\hookleftarrow"] = { "↩", "Identifier" },
	["\\hookrightarrow"] = { "↪", "Identifier" },
	["\\lmoustache"] = { "╭", "Identifier" },
	["\\P"] = { "¶", "Identifier" },
	["\\prime"] = { "′", "Identifier" },
	["\\quad"] = { " ", "Identifier" },
	["\\qquad"] = { " ", "Identifier" },
	["\\rmoustache"] = { "╮", "Identifier" },
	["\\smile"] = { "‿", "Identifier" },
	["\\star"] = { "✫", "Identifier" },
	["\\surd"] = { "√", "Identifier" },
	["\\top"] = { "⊤", "Identifier" },
	["\\triangleleft"] = { "⊲", "Identifier" },
	["\\triangleright"] = { "⊳", "Identifier" },
	["\\right"] = { "", "Identifier" },
	["\\left"] = { "", "Identifier" },
	--command_delim
	["\\frac"] = function(buffer, node)
		concealer.delim[1](buffer, node, { "(", "Special" })
		concealer.delim[2](buffer, node, { ")/(", "Special" })
		concealer.delim[3](buffer, node, { ")", "Special" })
	end,
	["\\abs"] = function(buffer, node)
		concealer.delim[1](buffer, node, { "|", "Special" })
		concealer.delim[2](buffer, node, { "|", "Special" })
	end,
	["\\ref"] = { delim = { "🔗", "🔗" } },
	--fonts
	["\\mathbb"] = function(buffer, node)
		concealer.filter[0](buffer, node, filters.mathbb, "Special")
	end,
	["\\mathcal"] = function(buffer, node)
		concealer.filter[0](buffer, node, filters.mathcal, "Special")
	end,
	["\\mathbbm"] = function(buffer, node)
		concealer.filter[0](buffer, node, filters.mathbbm, "Special")
	end,
	["\\mathfrak"] = function(buffer, node)
		concealer.filter[0](buffer, node, filters.mathfrak, "Special")
	end,
	["\\mathscr"] = function(buffer, node)
		concealer.filter[0](buffer, node, filters.mathscr, "Special")
	end,
	["\\mathsf"] = function(buffer, node)
		concealer.filter[0](buffer, node, filters.mathsf, "Special")
	end,
}
