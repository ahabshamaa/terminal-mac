# Fork notes (ahabshamaa/terminal-mac)

Personal fork of [govijr/terminal-mac](https://github.com/govijr/terminal-mac), forked at `cdad51f` (v0.2.0 build 6, 2026-11-05).
Sync with `bash scripts/sync-upstream.sh` (upstream has no changelog; commits are the release notes).

Local setup on this Mac (2026-11-06): host macOS 27.2 (26B123), Xcode 27.0, Swift 6.4, signed with the
self-signed "Govijr Code Signing" identity created by `scripts/create-signing-identity.sh` (back it up:
Keychain Access → My Certificates → Export, or guest permissions must be re-granted after a new identity).
Guest restore image: macOS 27.2 (26B123), 23.8 GiB.

Known upstream issues, with reproduction attempts here (guest: macOS 27.2 26B123, 4 CPUs, 4 GiB,
64 GiB disk, 2x HiDPI 1280×800 points). Not fixed yet; each has a root-cause pointer into the code.
Summary: **neither #4 nor #6 reproduced** on this Mac. A third, new problem (intermittent `type`) did.
All line numbers are against `cdad51f`. Guest code lives in `Sources/TerminalMac/Guest.swift`
(issue #6 mentions `Sources/TerminalMacGuest/`, which does not exist; host and guest share one executable).

---

## (a) `action key` chords and Backspace/Delete have no effect in focused web inputs (upstream #4)

Upstream: https://github.com/govijr/terminal-mac/issues/4 (open). Reported on guest macOS 26, Chrome.

### Reproduction on this Mac (2026-11-06): NOT reproduced in Safari; Chrome not yet tested

Driven through `terminal-mac mcp default` (`key`/`click`/`type` tools). Guest **Safari**, duckduckgo.com
search `<input>`, focused with `click`:

| Step | Result |
|---|---|
| `type "typed"`, then `key` t,w,o,f,i,v,e,z,e,r,o | field shows `typedtwofivezero` |
| `key backspace` ×2 | `typedtwofiveze` (works) |
| `key delete` at end of field | no change (expected: 117 is forward delete, see pointer 4) |
| `key cmd+a` | whole value selected (works) |
| `key x` | value replaced by `x` (works) |

Native apps: `cmd+space` (Spotlight), `cmd+n` (TextEdit), `cmd+l` (Safari address bar), `cmd+a` and
`backspace` in TextEdit all worked. The report is Chrome on a macOS 26 guest; Chrome is not installed in
this guest. **To finish:** install Chrome in the guest and repeat the table on a prefilled `<input>`.
If it fails only in Chrome, pointers 1–3 (Chromium-specific modifier/event-source handling) are the
leading suspects; Safari/AppKit evidently accept the current events.

### Root-cause pointers (hypotheses from reading the code, not yet confirmed by a fix)

All key handling is `GuestRuntime.press(_:)`, `Sources/TerminalMac/Guest.swift:205-222`.

1. **Modifiers are only flags, never keys.** `press` posts exactly two events (key down, key up) for the
   final key, with `event.flags = flags` (`Guest.swift:218-221`). It never posts the modifier key itself
   (`kVK_Command` 55, `kVK_Shift` 56, `kVK_Option` 58, `kVK_Control` 59) or the `.flagsChanged` events a
   physical keyboard produces. AppKit menu key equivalents read flags off the event, so chords can work
   in native apps while web content that tracks modifier state from `flagsChanged` sees a plain key.
   Likely fix: post modifier down (`flagsChanged`), key down, key up, modifier up, each with cumulative flags.
2. **No event source.** Every event uses `CGEvent(keyboardEventSource: nil, …)` (`Guest.swift:219`, also
   `type` at `:169-170` and mouse at `:201`). Session modifier state (`CGEventSource.flagsState`) is then
   never updated by the posted events. Likely fix: one shared `CGEventSource(stateID: .hidSystemState)`.
3. **Down and up are posted back-to-back with no delay** (`Guest.swift:218-221`). Upstream's own `drag`
   already sleeps 8 ms between steps (`:152`). Likely fix: a few ms between down and up.
4. **Key naming:** `"delete"` maps to 117, which is *forward* delete (`kVK_ForwardDelete`), not the Mac
   "delete" key (`"backspace"` → 51) (`Guest.swift:227`). `key delete` at the end of a field does nothing.
5. **Menu clicks (secondary symptom in #4):** `click` posts mouse down/up with no prior `mouseMoved`
   (`Guest.swift:128-141`). NSMenu highlights items on movement, so a mouse-up on an item that was never
   hovered can leave the menu open. Likely fix: `.mouseMoved` to the point plus a short delay first.

---

## (b) `screenshot` fails with "No guest display is available" (upstream #6)

Upstream: https://github.com/govijr/terminal-mac/issues/6 (open), full text read 2026-11-06. Summary:
v0.2.0-6, host macOS 27.0, **guest macOS 27.2 (26B123)**, the same image this Mac installs.
`action status` reports `screenRecording: true`, `accessibility: true`, 1280×800, but
`action screenshot` exits 1 with `No guest display is available`, headless and with the native window
shown, 0/4 attempts across two VMs. Also reported: 32 GiB disk is too small for a 27.2 guest (helper
install fails "out of space"); graceful `stop` hung in `stopping` > 90 s and needed `--force`. Reporter
asks whether 27.x guests are supported (README says the build targets the macOS 26 SDK) and proposes a
`CGDisplayCreateImage`/`CGWindowListCreateImage` fallback.

### Reproduction on this Mac (2026-11-06): NOT reproduced

Same guest image as the report (27.2, 26B123), but a 64 GiB disk (the default), not 32 GiB.
`action status` → `screenRecording: true`, `accessibility: true`, 1280×800. Every screenshot succeeded:
about 15 via the MCP `screenshot` tool with the native window shown, plus 3/3 via
`terminal-mac action default screenshot` after `terminal-mac hide default`. Differences from the
report that may matter: setup via Setup Assistant on a fresh 64 GiB VM (no disk grow, no APFS clone
with a regenerated `VZMacMachineIdentifier`), guest logged in interactively, helper launched from
`/Volumes/My Shared Files/tools` once. Graceful `stop` not yet tested.

### Root-cause pointers

1. **The failing check:** `Guest.swift:117-118`. `SCShareableContent.excludingDesktopWindows(false,
   onScreenWindowsOnly: true)` returns an empty `displays` array, so both
   `first(where: displayID == CGMainDisplayID())` and the `content.displays.first` fallback are nil and
   the generic error is thrown. The live viewer path has the same code and error at
   `Sources/TerminalMac/GuestCapture.swift:46-47`, so the terminal viewer should fail the same way.
2. **Two different permission checks:** `status` (`Guest.swift:97-101`) and the screenshot guard
   (`:103`, `:116`) use `CGPreflightScreenCaptureAccess()` (CoreGraphics TCC). ScreenCaptureKit's content
   enumeration is a separate path. A true preflight with empty SCK content means they disagree, and the
   code reports readiness from one and fails on the other. Why they disagree on a 27.2 guest: not verified.
3. **No relaunch after grant:** the helper requests access from its button (`Guest.swift:83-86`) in the
   same process that later enumerates content, and only relaunches on a self-update
   (`GuestBootstrap.updateFromSharedTools`). Whether SCK needs a relaunch here: not verified.
4. **Error quality:** `Failure("No guest display is available")` (`Guest.swift:118`,
   `GuestCapture.swift:47`) omits `content.displays.count` and `CGMainDisplayID()`, so a report cannot
   tell "SCK returned nothing" from "SCK returned a different display".

---

## (c) New, not filed upstream: `type` intermittently inserts nothing

### Reproduction on this Mac (2026-11-06)

Right after guest setup, `type` returned `Done: type.` (no error) but inserted nothing, 4 times in a row:
twice into Spotlight's field (after `cmd+space`, and again after clicking into the field), once via MCP
and once via `terminal-mac action default type 'X'` into a focused TextEdit document. In the same
fields, per-letter `key` events (`key t`, `key e`, …) worked immediately. A few minutes later `type`
worked in a Safari web input and then in TextEdit (`hello from Claude`). Trigger not isolated: it is
not known whether it was time since login, the first-run Spotlight intro, or something the per-letter
`key` events changed.

### Root-cause pointers

1. `type` (`Guest.swift:162-179`) posts `CGEvent(keyboardEventSource: nil, virtualKey: 0, …)` with
   `keyboardSetUnicodeString` on the key-down only; the key-up has no string (`:169-172`). The text
   depends entirely on the receiver honoring the Unicode override on a keycode-0 ("a") event.
2. Same nil event source as (a) pointer 2: no session keyboard state, so an input source or IME that
   is not yet initialized after login may drop the override. Not verified.
3. The reply is success whenever the events were posted (`Guest.swift:185`), so agents get
   `Done: type.` for text that never arrived. Agents should screenshot after typing (the skill already
   says to verify).
