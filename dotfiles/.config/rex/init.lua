local leader = "ctrl+space"

rex.bind(leader .. ">" .. leader, "pane.send_key", { key = leader })
rex.bind(leader .. ">shift+'", "pane.split", { direction = "down" })
rex.bind(leader .. ">shift+5", "pane.split", { direction = "right" })
rex.bind(leader .. ">z", "pane.zoom")
rex.bind(leader .. ">x", "pane.close")

rex.bind(leader .. ">c", "client.tab.new")
rex.bind(leader .. ">s", "session.switch")

-- leader + 1..9 -> go to that tab *within the current session* (tmux-style).
-- (client.tab.goto indexes the flat tab list across all sessions.)
rex.action({
	name = "session_tab_goto",
	title = "Go to Tab in Current Session",
	run = function(ctx, args)
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
	rex.bind(leader .. ">" .. i, "session_tab_goto", { index = i })
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
rex.bind(leader .. ">g", "lazygit_float")

-- tmux-style copy mode: capture the focused block's screen+scrollback to a temp file
-- and open it read-only in nvim in a floating layer. q quits (closes the layer).
rex.action({
	name = "copy_mode",
	title = "Copy Mode (nvim scrollback)",
	run = function(ctx, args)
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
		-- VT rendered in an nvim terminal buffer: colors display, but yanks copy plain text.
		local script = table.concat({
			'nvim -n -c "set scrollback=100000 nonumber norelativenumber signcolumn=no"'
				.. ' -c "autocmd TermClose * stopinsert | normal! G"'
				.. ' -c "autocmd TermOpen * nnoremap <buffer> q :qa!<CR>"'
				.. ' -c "terminal cat \\"$1\\""',
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
rex.bind(leader .. ">[", "copy_mode")

--- TODO: rex theming declaratively?
