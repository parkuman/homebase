local leader = "ctrl+space"

-- Leader is a one-shot key *mode* ("leader") rather than a key sequence, so we get to run code
-- when it opens: tabs of the current session get a "[N] " prefix so leader+N is obvious.
-- Every binding in the mode (and every action bound there) must call leave_leader() to drop the
-- hints and exit the mode. Escape cancels. Mode is exclusive, so stray keys never reach the shell.
local hint_state = (os.getenv("TMPDIR") or "/tmp") .. "/rex-leader-labels.json"

local function read_saved()
	local fh = io.open(hint_state, "rb")
	if fh == nil then
		return {}
	end
	local text = fh:read("*a")
	fh:close()
	return rex.json.decode(text) or {}
end

-- Restore the labels saved by show_tab_hints (only if the tab still shows our prefix).
local function clear_tab_hints()
	local saved = read_saved()
	if next(saved) == nil then
		return
	end
	local view = rex.session.view({})
	for _, win in ipairs((view and view.windows) or {}) do
		local orig = saved[win.window_id]
		if orig ~= nil and (win.label or ""):match("^%[%d%] ") then
			rex.session.set_window_label({ window_id = win.window_id, label = orig })
		end
	end
	os.remove(hint_state)
end

local function show_tab_hints()
	clear_tab_hints()
	local view, verr = rex.session.view({})
	if view == nil then
		error(verr, 0)
	end
	local saved = {}
	for i, win in ipairs(view.windows or {}) do
		if i > 9 then
			break
		end
		local label = win.label or ""
		-- Default labels ("Window <id>") are not what the tab shows (it shows the terminal title),
		-- so number the title; restoring "" brings the default back.
		local base = label
		if label:match("^Window %x+$") then
			local t = win.focused_block_id
				and rex.block.call("com.superlogical.terminal", "title", { block_id = win.focused_block_id })
			base = (t and t.title ~= "" and t.title) or label
			saved[win.window_id] = ""
		else
			saved[win.window_id] = label
		end
		rex.session.set_window_label({ window_id = win.window_id, label = "[" .. i .. "] " .. base })
	end
	local fh = io.open(hint_state, "wb")
	if fh ~= nil then
		fh:write(rex.json.encode(saved))
		fh:close()
	end
end

local function leave_leader()
	clear_tab_hints()
	rex.client.queue("client.mode.exit")
end

rex.action({
	name = "leader_open",
	title = "Leader (show tab numbers)",
	run = function()
		show_tab_hints()
		rex.client.queue("client.mode.enter", { name = "leader" })
	end,
})

-- Wrapper for built-in client actions: drop hints, exit the mode, then run the action.
rex.action({
	name = "leader_run",
	title = "Leader: run action",
	run = function(ctx, args)
		leave_leader()
		if args ~= nil and args.action ~= nil then
			rex.client.queue(args.action, args.args)
		end
	end,
})

rex.mode("leader", { exclusive = true })
rex.bind(leader, "leader_open")

local function lbind(key, action, args)
	rex.bind("leader/" .. key, "leader_run", { action = action, args = args })
end

rex.bind("leader/escape", "leader_run")
lbind(leader, "pane.send_key", { key = leader })
lbind("shift+'", "pane.split", { direction = "down" })
lbind("shift+5", "pane.split", { direction = "right" })
lbind("z", "pane.zoom")
lbind("x", "pane.close")

lbind("c", "client.tab.new")
lbind("s", "session.switch")
lbind("r", "session.rename")

-- leader + 1..9 -> go to that tab *within the current session* (tmux-style).
-- (client.tab.goto indexes the flat tab list across all sessions.)
rex.action({
	name = "session_tab_goto",
	title = "Go to Tab in Current Session",
	run = function(ctx, args)
		leave_leader()
		local view, verr = rex.session.view({})
		if view == nil then
			error(verr, 0)
		end
		local index = tonumber(args.index)
		if index > #(view.windows or {}) then
			return -- no such tab in this session: do nothing
		end
		-- Translate to the flat index: tabs of all earlier sessions come first.
		local offset = 0
		local list, lerr = rex.call("session.list")
		if list == nil then
			error(lerr, 0)
		end
		for _, s in ipairs(list.sessions or {}) do
			if s.session_id == view.session_id then
				break
			end
			local v = rex.session.view({ session_id = s.session_id })
			offset = offset + #((v and v.windows) or {})
		end
		rex.client.queue("client.tab.goto", { index = offset + index })
	end,
})
for i = 1, 9 do
	rex.bind("leader/" .. i, "session_tab_goto", { index = i })
end

-- vim-like pane navigation (ctrl+h/j/k/l)
-- requires https://github.com/baggiponte/rex-navigator.nvim to work well with neovim
rex.bind("ctrl+h", "pane.focus.left")
rex.bind("ctrl+j", "pane.focus.down")
rex.bind("ctrl+k", "pane.focus.up")
rex.bind("ctrl+l", "pane.focus.right")

-- https://github.com/baggiponte/rex-navigator.nvim
local data = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
local plugin = data .. "/nvim/lazy/rex-navigator.nvim"
local ok, err = pcall(function()
	dofile(plugin .. "/rex/navigator.lua").setup()
end)
if not ok then
	rex.log("warn", "rex-navigator not loaded: " .. tostring(err))
end

-- lazygit in a floating layer (toggle).
-- none -> open; open+focused -> minimize (blocks keep running); otherwise -> restore + focus.
-- While minimized you can use other panes / copy text, then press the key again.
rex.action({
	name = "lazygit_float",
	title = "Toggle Floating Lazygit",
	run = function(ctx, args)
		leave_leader()
		local view, verr = rex.session.view({})
		if view == nil then
			error(verr, 0)
		end

		for _, win in ipairs(view.windows or {}) do
			for _, layer in ipairs(win.layers or {}) do
				if layer.kind ~= "tiled" then
					for _, b in ipairs(layer.blocks or {}) do
						if b.label == "lazygit" then
							local has_focus = win.focused_block_id == b.block_id
								and view.active_window_id == win.window_id
							if layer.state ~= "minimized" and has_focus then
								local _, err =
									rex.session.set_layer_state({ layer_id = layer.layer_id, state = "minimized" })
								if err ~= nil then
									error(err, 0)
								end
							else
								local _, err = rex.session.set_layer_state({
									layer_id = layer.layer_id,
									state = "normal",
									focus = true,
								})
								if err ~= nil then
									error(err, 0)
								end
							end
							return
						end
					end
				end
			end
		end

		local cwd
		if ctx.block_id ~= nil then
			local r = rex.block.call("com.superlogical.terminal", "pwd", { block_id = ctx.block_id })
			if r ~= nil then
				cwd = r.pwd or r.path or r.cwd
			end
			if cwd == nil or cwd == "" then
				local p = rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
				if p ~= nil and p.foreground ~= nil then
					cwd = p.foreground.cwd
				end
			end
		end

		local _, err = rex.session.new_layer({
			bounds = { 0.05, 0.05, 0.9, 0.9 },
			focus = true,
			layout = rex.layout.block({
				flavor = "com.superlogical.terminal.shell",
				label = "lazygit",
				options = { command = { "lazygit" }, cwd = cwd },
			}),
		})
		if err ~= nil then
			error(err, 0)
		end
	end,
})
rex.bind("leader/g", "lazygit_float")

-- tmux-style copy mode: capture the focused block's screen+scrollback to a temp file
-- and open it as an editable, colored buffer in nvim in a floating layer.
-- Edit freely, visually select + yank what you want. q quits (closes the layer, discards edits).
rex.action({
	name = "copy_mode",
	title = "Copy Mode (editable nvim scrollback)",
	run = function(ctx, args)
		leave_leader()
		if ctx.block_id == nil then
			error("no focused block", 0)
		end
		-- Capture NOW, before the layer opens: opening it un-zooms the source pane, which resizes
		-- it and makes the program redraw narrow before a shell-side capture could run.
		local cap, cerr = rex.block.call("com.superlogical.terminal", "format", {
			block_id = ctx.block_id,
			format = "vt",
			trim = true,
			unwrap = true,
		})
		if cap == nil then
			error(cerr or "capture failed", 0)
		end
		local path = os.tmpname()
		local fh, ferr = io.open(path, "wb")
		if fh == nil then
			error(ferr, 0)
		end
		fh:write(cap.content)
		fh:close()
		-- VT capture loaded into a normal (editable) nvim buffer; copy_mode_ansi.lua strips the
		-- escapes and re-applies the colors as highlights. Jumps to the bottom. No swap file;
		-- yanks go to the system clipboard. q quits without saving.
		local script = table.concat({
			'nvim -n -c "set nonumber norelativenumber signcolumn=no clipboard=unnamedplus"'
				.. ' -c "nnoremap <buffer> q :qa!<CR>"'
				.. ' -c "luafile ' .. (os.getenv("HOME") .. "/.config/rex/copy_mode_ansi.lua") .. '"'
				.. ' -c "normal! G" "$1"',
			'rm -f "$1"',
		}, "; ")
		local _, err = rex.session.new_layer({
			bounds = { 0.02, 0.03, 0.96, 0.94 },
			focus = true,
			layout = rex.layout.block({
				flavor = "com.superlogical.terminal.shell",
				label = "copy-mode",
				options = { command = { "sh", "-c", script, "sh", path } },
			}),
		})
		if err ~= nil then
			error(err, 0)
		end
	end,
})
rex.bind("leader/[", "copy_mode")

--- TODO: rex theming declaratively?
