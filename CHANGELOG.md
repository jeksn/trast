# Changelog

## v0.6.0 — Rename to Trast (Sep 17, 2026)

- Renamed from WindowPane to Trast across the entire app
- New bundle ID `com.trast.app` and URL scheme `trast://`
- Config migration: existing WindowPane settings auto-copied to Trast on first launch
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
