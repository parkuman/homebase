-- Colorize the current buffer from raw VT/ANSI escapes, then strip the escapes so the
-- buffer is plain, editable text. Colors are extmark highlights (survive edits).
local buf = vim.api.nvim_get_current_buf()
local ns = vim.api.nvim_create_namespace("rex_copy_mode_ansi")

-- Rex's terminal theme (gruvbox dark), queried via OSC 4/10/11. Update if the Rex theme changes.
local default_fg, default_bg = "#ebdbb2", "#282828"
local base16 = {
	"#282828", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984",
	"#928374", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#ebdbb2",
}
local function idx_color(n)
	if n < 16 then
		return base16[n + 1]
	elseif n < 232 then
		n = n - 16
		local function lv(v) return v == 0 and 0 or 55 + v * 40 end
		return string.format("#%02x%02x%02x", lv(math.floor(n / 36)), lv(math.floor(n / 6) % 6), lv(n % 6))
	end
	local g = 8 + (n - 232) * 10
	return string.format("#%02x%02x%02x", g, g, g)
end

local function new_style() return {} end
local function copy(s) return vim.deepcopy(s) end

local function apply_sgr(st, params)
	local p = {}
	for _, v in ipairs(vim.split(params == "" and "0" or params, "[;:]")) do
		p[#p + 1] = tonumber(v) or 0
	end
	local i = 1
	while i <= #p do
		local c = p[i]
		if c == 0 then
			for k in pairs(st) do st[k] = nil end
		elseif c == 1 then st.bold = true
		elseif c == 3 then st.italic = true
		elseif c == 4 then st.underline = true
		elseif c == 7 then st.reverse = true
		elseif c == 9 then st.strikethrough = true
		elseif c == 22 then st.bold = nil
		elseif c == 23 then st.italic = nil
		elseif c == 24 then st.underline = nil
		elseif c == 27 then st.reverse = nil
		elseif c == 29 then st.strikethrough = nil
		elseif c >= 30 and c <= 37 then st.fg = idx_color(c - 30)
		elseif c >= 90 and c <= 97 then st.fg = idx_color(c - 90 + 8)
		elseif c >= 40 and c <= 47 then st.bg = idx_color(c - 40)
		elseif c >= 100 and c <= 107 then st.bg = idx_color(c - 100 + 8)
		elseif c == 39 then st.fg = nil
		elseif c == 49 then st.bg = nil
		elseif c == 38 or c == 48 then
			local key = c == 38 and "fg" or "bg"
			if p[i + 1] == 2 and p[i + 4] then
				st[key] = string.format("#%02x%02x%02x", p[i + 2], p[i + 3], p[i + 4])
				i = i + 4
			elseif p[i + 1] == 5 and p[i + 2] then
				st[key] = idx_color(p[i + 2])
				i = i + 2
			end
		end
		i = i + 1
	end
end

local hl_cache, hl_defs = {}, {}
local function hl_for(st)
	if next(st) == nil then return nil end
	local key = table.concat({
		st.fg or "", st.bg or "", st.bold and "b" or "", st.italic and "i" or "",
		st.underline and "u" or "", st.reverse and "r" or "", st.strikethrough and "s" or "",
	}, "|")
	if not hl_cache[key] then
		local name = "RexCopyAnsi" .. vim.tbl_count(hl_cache)
		hl_defs[name] = {
			fg = st.fg, bg = st.bg, bold = st.bold, italic = st.italic,
			underline = st.underline, reverse = st.reverse, strikethrough = st.strikethrough,
		}
		vim.api.nvim_set_hl(0, name, hl_defs[name])
		hl_cache[key] = name
	end
	return hl_cache[key]
end

-- Match the terminal's default colors so unstyled text looks like it did in the pane.
local function apply_defaults()
	for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "EndOfBuffer", "SignColumn" }) do
		vim.api.nvim_set_hl(0, group, { fg = default_fg, bg = default_bg })
	end
	for name, def in pairs(hl_defs) do
		vim.api.nvim_set_hl(0, name, def)
	end
end
apply_defaults()
-- A (lazy-loaded) colorscheme may land after this script runs; re-apply when it does.
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter", "User" }, {
	callback = function(ev)
		if ev.event ~= "User" or ev.match == "VeryLazy" then
			vim.schedule(apply_defaults)
		end
	end,
})

local src = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local out, spans = {}, {}
local st = new_style()

for lnum, line in ipairs(src) do
	line = line:gsub("\r$", "")
	local text, line_spans = {}, {}
	local col, pos = 0, 1
	local seg_start, seg_style = 0, copy(st)
	local function close(at)
		if at > seg_start and next(seg_style) ~= nil then
			line_spans[#line_spans + 1] = { seg_start, at, copy(seg_style) }
		end
	end
	while pos <= #line do
		local e = line:find("\27", pos, true)
		if not e then
			local chunk = line:sub(pos)
			text[#text + 1] = chunk
			col = col + #chunk
			break
		end
		if e > pos then
			local chunk = line:sub(pos, e - 1)
			text[#text + 1] = chunk
			col = col + #chunk
		end
		local params, final = line:match("^\27%[([0-9;:?<=>]*)[ -/]*([@-~])", e)
		if params then
			local whole = line:match("^\27%[[0-9;:?<=>]*[ -/]*[@-~]", e)
			if final == "m" then
				close(col)
				apply_sgr(st, params)
				seg_start, seg_style = col, copy(st)
			end
			pos = e + #whole
		elseif line:sub(e + 1, e + 1) == "]" then
			local _, oe = line:find("\7", e, true)
			local _, se = line:find("\27\\", e, true)
			pos = (oe and se and math.min(oe, se) or oe or se or #line) + 1
		else
			pos = e + 2
		end
	end
	close(col)
	out[lnum] = table.concat(text)
	spans[lnum] = line_spans
end

vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
for lnum, line_spans in ipairs(spans) do
	for _, s in ipairs(line_spans) do
		local hl = hl_for(s[3])
		if hl then
			vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, s[1], { end_col = s[2], hl_group = hl, priority = 200 })
		end
	end
end
vim.bo[buf].modified = false
