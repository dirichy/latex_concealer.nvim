# latex_concealer.nvim
More powerful conceal for latex code with neovim. 
![](./test/SCR-20250220-sfrc.png)

# dependencies
`nvim-treesitter` and parser for latex

> **Warning:** This plugin is still alpha, expect break changes and bugs! 
# install 
For example by `lazy.nvim`:
```lua 
{
  "dirichy/latex_concealer.nvim",
    ft={"tex","latex"},
    opts={},
    config=true,
}
```

# config
You can pass your own options to `opts`, the default opts following:
```lua
M.config = {
    ---To handle matched treesitter node
	handler = {
		---@type table<string,string[]|string>
        ---The key is treesitter node type, value is how to treat this node. 
        ---For generic_command, value is virt_text for conceal, see nvim_buf_set_extmark
		generic_command = {},
        ---For begin, value is function(buffer,node) to do some counter-related things. 
		begin = {
			enumerate = function(buffer, node)
				counter.item_depth_change(buffer, true, 1)
			end,
			itemize = function(buffer, node)
				counter.item_depth_change(buffer, false, 1)
			end,
		},
        ---For end, value is function(buffer,node) to do some counter-related things. 
		["end"] = {
			enumerate = function(buffer, node)
				counter.item_depth_change(buffer, true, -1)
			end,
			itemize = function(buffer, node)
				counter.item_depth_change(buffer, false, -1)
			end,
		},
	},
    ---To set concealcursor
	conceal_cursor = "nvic",
    ---Events to refresh
	refresh_events = { "InsertLeave", "BufWritePost" },
	local_refresh_events = { "TextChangedI", "TextChanged" },
	cursor_refresh_events = { "CursorMovedI", "CursorMoved" },
    ---Something about counters
    counter={
        ---Same as `\the` command in latex, but is turple of string. The second is hl_group to use. 
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
            enumiv = { "\\fnsymbol{enumiv}", "Special" },
        },
        ---For unordered list(itemize) conceal.
        unordered = {
            { "o", "ErrorMsg" },
            { "-", "Constant" },
            { "+", "DiagnosticHint" },
            { "=", "Special" },
            { "DON'T NEST LIST MORE THAN FOUR LAYER", "ErrorMsg" },
        },
    }
}
```
