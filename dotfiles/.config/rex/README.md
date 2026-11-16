# Rex config

Edit `init.lua`. Restarting the Rex UI does **not** reload it — the Rex server is a separate long-running process.

## Reload

```sh
rex config reload
```

## Useful commands

- `rex config check` — validate init.lua
- `rex keymap` — show resolved bindings
- `rex -C <client-label> actions` — list bindable actions (get label from `rex client ls`)

Keys set in the app's own settings override init.lua.
