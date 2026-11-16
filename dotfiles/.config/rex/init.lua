local leader = "ctrl+space"

rex.bind(leader .. ">" .. leader, "pane.send_key", { key = leader })
rex.bind(leader .. ">shift+'", "pane.split", { direction = "down" })
rex.bind(leader .. ">shift+5", "pane.split", { direction = "right" })
rex.bind(leader .. ">z", "pane.zoom")

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

--- TODO: rex theming declaratively?
