# Using terminal-mac

## MCP (recommended)

`terminal-mac mcp [NAME]` is a stdio Model Context Protocol server with computer-use tools for the guest desktop: `screenshot`, `click` (with `clicks: 2|3` and `button: right`), `move`, `drag`, `scroll`, `type`, `key` and `status`. Coordinates are pixels in the latest `screenshot`, which equal guest screen points. Action tools accept `screenshot: true` to return a fresh screenshot with the result. Register it once:

```bash
claude mcp add terminal-mac -- /absolute/path/to/terminal-mac mcp default
```

If a tool reports that the guest has no logged-in session, ask the user to sign in (`terminal-mac view NAME`, then Ctrl+O).

## Getting an app into the guest (fork addition)

There is no file-import action. Instead, the host folder `~/Developer/terminal-mac-apps` is shared **read-only** with the guest as `/Volumes/My Shared Files/apps`, next to `tools`:

1. On the host, copy the build into `~/Developer/terminal-mac-apps/` (for example `ditto MyApp.app ~/Developer/terminal-mac-apps/MyApp.app`).
2. In the guest, open it from Finder → `/Volumes/My Shared Files/apps`, or copy it to the guest's `/Applications` first if the app must write next to itself.

The share is attached when the VM starts, so create the folder before `terminal-mac start`; a running VM needs one shutdown and start to pick it up. Files added later appear in the guest immediately. `TERMINAL_MAC_APPS=/path` selects another folder. The VM refuses to start if that folder is the home folder, contains it, or is a git work tree, so the guest never sees your home or project folders.

## CLI and full instructions

The complete agent guide is the skill at [skills/terminal-mac/SKILL.md](../skills/terminal-mac/SKILL.md), which also ships inside the app (`terminal-mac skills get`). The CLI notes below are kept for reference.


Use `terminal-mac` for work inside an already configured virtual Mac. Obtain its absolute launcher path from the user/project environment; the development build is `dist/terminal-mac` relative to the repository.

1. Run `terminal-mac status NAME`. Start it with `terminal-mac start NAME` if stopped. Resume it if paused. For a new machine, `terminal-mac up NAME --no-view` handles downloading, installation, startup and readiness, with interactive guest setup by the user. Use `up --plan` to preview without changes.
2. Run `terminal-mac action NAME status`. Both guest permissions should be `true`. If the helper is unavailable, report that setup is needed; do not fall back to controlling the host desktop.
3. Run `terminal-mac action NAME screenshot --output /tmp/guest.png` and inspect the returned PNG with your image tool.
4. Choose a guest action using that screenshot's top-left coordinates:
   - `action NAME click X Y [--double] [--button right]`
   - `action NAME move X Y`
   - `action NAME drag X Y X2 Y2`
   - `action NAME type 'literal text'`
   - `action NAME key cmd+space` / `cmd+a` / `return` / `tab` / `escape`
   - `action NAME scroll --dy -300 --x X --y Y` (negative scrolls down)
5. Capture again after each meaningful action to confirm the result.

All replies are JSON; failures exit nonzero. Use normal safe shell quoting for literal text. `type --text 'value'` is also supported; `--` ends option parsing. Text uses Unicode input events, not the host clipboard. No shell-execution action is currently exposed.

Do not run the `guest` subcommand on the host. Do not use host screenshot or event-posting tools as a fallback. Apps, files and authenticated sessions inside the VM are separate from the user's physical Mac. Request user help for guest login, privacy permission prompts, or missing credentials.

`hide` and exiting `view` leave the VM running. `stop` requests shutdown. `stop --force` can lose guest work and should be used only when a normal shutdown cannot complete. This release candidate has no reset, clone, rollback, file import, or delete command.
