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

## Pi agent status + notifications

`agents/pi-rex-status.ts` makes pi report to Rex via terminal escapes:

- agent starts -> OSC 7501 `state=working` (sidebar icon = working)
- agent settled -> OSC 7501 `state=done` + OSC 777 desktop notification
- no-op outside Rex (needs `REX_BLOCK`)

Debug: `rex block call -b <block> program_status`.

Body format: `key=value` pairs joined by `:` (`state`, `app`, `kind`, `progress`; `msg`/`title` weren't accepted in testing).
