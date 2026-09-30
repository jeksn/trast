# Changelog

## v0.9.0 — Launcher calculator, live app list (Sep 30, 2026)

- Launcher calculator: type math (`2^10*2`), unit conversions (`5 km to miles`, `72 f`), or currency (`10 usd to eur`) in the launcher and press Return to copy the result; the result row appears above all other results
- Bare amounts (`25 eur`) convert to your base currency and bare units (`5 km`) follow your preferred unit system — both configurable in Settings → General → Calculator
- Currency rates are ECB daily reference rates, fetched at most once a day, cached on disk, and usable offline
- Apps installed while Trast is running now appear in the launcher without a relaunch — app directories are watched, rescans are debounced so half-copied bundles are never picked up, and existing entries are reused so only new apps pay the load

## v0.8.0 — Scratchpad, launcher performance (Sep 29, 2026)

- Launcher Scratchpad: a category for jotting quick notes, with its own hotkey (Settings → Scratchpad to record it), copy-to-clipboard and clear buttons; text persists between opens
- Launcher performance: results are computed once per keystroke from a precomputed search index instead of re-ranking every item on every row render — search and arrow-key navigation now track keystrokes with no lag; searching inside a category only scores that category's items
- Snippet expansion reworked: selects the typed keyword and pastes the expansion in one shot instead of backspacing and typing — fixes keyword residue in browser address bars and multiline-safe, single-frame expansion; clipboard history stays clean (pasteboard saved and restored)
- Next Window cycling fixed for apps with three or more windows: a stable per-app round-robin order replaces the z-order-following index math that degraded to toggling the top two windows
- App icons downsampled once at scan time instead of rescaling full-size icons on every row render

## v0.7.0 — Native hyper key (Sep 22, 2026)

- Caps Lock → ⌃⌥⇧⌘: hold Caps Lock as a "hyper" modifier, a combo no other app uses, and bind conflict-free hotkeys to window commands and shortcuts; a lone Caps Lock tap does nothing (Settings → General → Hyper Key)
- While the hyper key is enabled, Caps Lock is remapped at the driver level (to F18) so the lock state and LED stay off; reverts when disabled or Trast quits
- Hyper combos display as ✦K in the command list, Launcher, and the shortcut recorder — record Caps Lock + key directly
- Custom hotkey recorder replaces KeyboardShortcuts.Recorder everywhere: same storage, ✦ rendering, menu key equivalents (⌘W etc.) record instead of firing, no packaged-app resource bundle crash
- Requires Accessibility and Input Monitoring permissions; quit Hyperkey.app or other Caps Lock remappers first

## v0.6.0 — Rename to Trast (Sep 17, 2026)

- Renamed from Trast to Trast across the entire app
- New bundle ID `com.trast.app` and URL scheme `trast://`
- Config migration: existing Trast settings auto-copied to Trast on first launch
- Dynamic accessibility status in the menu bar (updates without relaunch)
- Removed app name from the settings window title

## v0.5.0 — Launcher redesign, snippet hardening (Sep 17, 2026)

- Two-mode launcher: search and actions grid with Tab to switch, animated blur-and-fade transitions
- Clipboard and Snippets tabs integrated into the launcher with live content
- Cmd+1..6 to jump to a category from anywhere
- Recent items shown when entering a category without typing
- Rotating placeholder text in the search bar
- Snippet expansion hardened: buffer resets on mouse clicks and app switches, private CGEventSource to prevent key suppression, magic tag to avoid self-feedback
- Snippet template variables: `{{clipboard}}`, `{{date}}`, `{{date -1}}`, `{{time}}`, custom date formats
- Clipboard History fixed in All tab, clipboard deduplication improvements
- Settings opening from launcher reliability fix

## v0.4.0 — Launcher: apps, clipboard, snippets (Sep 16, 2026)

- Spotlight-style launcher replaces the Quick Picker as the main interface
- App launching: search and launch any installed app with real icons
- Clipboard history: polls pasteboard, stores up to 100 items, searchable in the launcher, paste-on-select
- Snippet expansion: type a keyword to expand into predefined text (requires Input Monitoring permission)
- Edge gap presets: Small (10px), Medium (20px), Large (40px), Extra Large (60px)
- Inter-window gap support in LayoutEngine (not yet exposed in CommandApplier)
- Launcher transparency slider (5% steps)
- Settings redesigned as 3-column app layout with section headings
- Slimmed down menu bar, Launcher promoted to primary interface

## v0.3.0 — Presets, Next Display, export/import (Sep 14, 2026)

- Command presets: quick-apply common layouts from the launcher
- Next Display action: move the focused window to the next display, preserving relative position and size
- Config export/import: back up and restore commands and shortcuts as JSON
- Recently-used ordering in the launcher with UsageTracker
- Fuzzy match highlighting in search results
- App shortcuts submenu in the menu bar
- Next Window menu item
- Auto-update check on launch
- Native menu key equivalents for pinned commands

## v0.2.0 — App, URL, and folder shortcuts (Sep 10, 2026)

- App shortcuts: bind global hotkeys to launch or activate apps
- URL/Link shortcuts: open a URL from a global hotkey
- Folder/File shortcuts: open files and folders in Finder or their default app
- Next Window global hotkey: cycle through the front app's windows via Accessibility (independent of the system shortcut)

## v0.1.4 — CI fixes (Sep 6, 2026)

- Fixed resource bundle patch target for CI builds

## v0.1.0–v0.1.3 — Initial release (Sep 6, 2026)

- Window management: custom commands with two-axis anchors, percent/point sizes, X/Y offsets
- 27 built-in commands (halves, quarters, thirds, sixths, maximize, center, move)
- Global hotkeys per command, recorded in-app
- Menu bar pinning: choose which commands appear in the menu bar
- Restore: undo the last window change per window
- Settings UI with command editor and live preview
- In-app Check for Updates
- Release pipeline with GitHub Actions (build, test, DMG, auto-publish)
- Stable code signing support
- App icon and menu bar icon
