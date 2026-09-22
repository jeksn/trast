# Trast

Window management and a Spotlight-like launcher for macOS.

Resize and move the focused window into any layout you define — halves, thirds, sixths, or custom percentages with offsets — and trigger your presets with global hotkeys, the Launcher, or a URL. The Launcher also searches and launches installed apps, manages clipboard history, and expands text snippets. A native hyper key turns Caps Lock into ⌃⌥⇧⌘ for conflict-free hotkeys.

## Features

### Window management

- **Custom window commands** — size in % of the display or absolute points, a two-axis anchor (pin left/center/right and top/center/bottom independently, or keep either axis to build move-style commands), and X/Y offsets with negative values
- **27 built-in commands** — halves, corner quarters, column fourths, thirds, sixths, Maximize / Maximize Height / Maximize Width, Center, Reasonable Size, and Move Left/Right/Up/Down — all editable, hideable, deletable, and restorable
- **Global hotkeys** per command, recorded in-app
- **Next Window hotkey** — cycle through the front app's windows via Accessibility, independent of the system "Move focus to next window" shortcut
- **Next Display** — move the focused window to the next display, preserving its relative position and size
- **Menu bar pinning** — choose exactly which commands appear in the menu bar
- **Restore** — undo the last window change, per window
- **Edge gap** — keep windows off the screen edges with presets (Small, Medium, Large, Extra Large)

### Launcher

- **Spotlight-style launcher** — press a global hotkey to open a search bar; results appear below as you type. Search across window commands, actions, shortcuts, installed apps, clipboard history, snippets, and the category views themselves (type "snippets" or "commands" to jump straight into that view)
- **Actions view** — press Tab to fade the search bar into a 2-column grid of categories (Window Commands, Shortcuts, Apps, Clipboard, Snippets, Trast) with ⌘-number badges. Tab scrolls through the options: each press advances to the next tile, and past the last one it wraps back to search (Shift+Tab cycles backward, and from inside a category Tab continues from the neighbouring tile). Arrows also navigate, Return enters a category, and Cmd+1..6 jumps to a category from anywhere; typing is ignored while the grid is shown. Esc from a category returns to the actions grid on that category's tile; Esc from the grid or search closes. Mode switches animate with a blur-and-fade transition
- **Recent activity** — entering a category without typing shows recently used items from that category, so the launcher feels alive instead of empty; the search bar is focused so you can start filtering immediately. Searching inside a category only searches that category's items; the main search fuzzy-searches everything
- **App launching** — search and launch any installed app with real app icons; apps with shortcuts show their hotkey
- **Clipboard history in launcher** — the Clipboard tab shows the full clipboard history (up to the configured limit) directly in the launcher; search matches the full content of each item, not just the first line; select to paste into the frontmost app. The dedicated clipboard hotkey (Settings → Window) opens the Launcher on the Clipboard tab — the launcher is the only clipboard interface
- **Snippets in launcher** — the Snippets tab shows all enabled snippets; select to copy the expanded text to the clipboard
- **Launcher transparency** — adjust the panel opacity from the General settings (slider with 5% steps)
- **Cmd+,** — open Settings directly from the Launcher

### Snippets

- **Text expansion** — type a keyword anywhere on the system and it expands into predefined text. Requires Input Monitoring permission (prompted on first enable in Settings → General)
- **Template variables** — insert dynamic content into your snippets using `{{variable}}` syntax:

| Variable | Result | Example |
| --- | --- | --- |
| `{{clipboard}}` | Current clipboard text | `{{clipboard}}` pastes whatever you copied |
| `{{date}}` | Today's date (yyyy-MM-dd) | `{{date}}` → 2026-09-16 |
| `{{date -1}}` | Yesterday | `{{date -1}}` → 2026-09-15 |
| `{{date +7}}` | One week ahead | `{{date +7}}` → 2026-09-23 |
| `{{date:MMMM d, yyyy}}` | Custom date format | `{{date:MMMM d, yyyy}}` → September 16, 2026 |
| `{{date -1:yyyy/MM/dd}}` | Offset with custom format | `{{date -1:yyyy/MM/dd}}` → 2026/09/15 |
| `{{time}}` | Current time (HH:mm:ss) | `{{time}}` → 14:32:05 |

  Date formats use standard ICU/DateFormatter patterns. Unknown variables (e.g. `{{unknown}}`) pass through as-is.

- **Snippet management** — create, edit, enable/disable, and delete snippets in Settings → Snippets. Each snippet has a name, a keyword (what you type to trigger it), and the content (with optional template variables)
- **Launcher integration** — snippets appear in the Snippets tab and in All search results; selecting from the launcher copies the resolved text to the clipboard

### Hyper key

- **Caps Lock → ⌃⌥⇧⌘** — hold Caps Lock as a "hyper" modifier, a combo no other app uses, and bind conflict-free hotkeys to your window commands and shortcuts. A lone Caps Lock tap does nothing (Settings → General → Hyper Key)
- **✦ display** — hyper combos render as `✦K` in the command list, the Launcher, and Trast's built-in shortcut recorder; record them directly by holding Caps Lock while recording
- **No lock, no LED** — while enabled, Caps Lock is remapped at the driver level (to F18) so the lock state and LED stay off; this reverts when the hyper key is disabled or Trast quits, and replaces any Caps Lock remap from System Settings → Keyboard → Modifier Keys while active
- Requires Accessibility and Input Monitoring permissions; quit other Caps Lock remappers (e.g. Hyperkey.app) first — two active remappers on the same key conflict

### Other

- **App, URL & Folder shortcuts** — bind global hotkeys to launch/activate an app, open a URL, or open a folder or file in Finder / its default app
- **URL scheme** — apply commands from scripts, shells, or other apps
- **Export / Import** — back up and restore all commands and shortcuts to a JSON file
- **Launch at login**
- **Check for Updates** — in-app updater that downloads and installs new releases from GitHub
- Native SwiftUI menu-bar app (no Dock icon, ~zero footprint)

## Requirements

- macOS 13 Ventura or later (developed on macOS 26)
- To build: Xcode Command Line Tools — full Xcode is **not** required

## Install from source

```bash
git clone <repo-url>
cd trast
Scripts/package_app.sh        # release build → ./Trast.app
Scripts/install.sh --force    # copy to /Applications
```

Launch the app and grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility). Window control on macOS requires it. Snippet expansion and the hyper key additionally require **Input Monitoring** permission (prompted on first enable).

### Stable permissions across rebuilds (recommended)

Ad-hoc–signed builds lose their Accessibility grant on every rebuild (macOS keys the grant to the binary's signature hash). Fix it once by signing with a self-signed certificate:

1. Keychain Access → **Certificate Assistant → Create a Certificate…**
2. Name: `Trast` · Identity Type: **Self Signed Root** · Certificate Type: **Code Signing**
3. Export the identity and build:

```bash
echo 'export CODESIGN_IDENTITY="Trast"' >> ~/.zshrc
source ~/.zshrc
Scripts/update.sh
```

Alternatively, put the certificate name in `Scripts/codesign-identity` (git-ignored) — the build script picks it up automatically.

Re-grant Accessibility one last time — after that, rebuilds keep the permission.

## Usage

- **Menu bar icon** — lists the commands you've pinned (toggle per command in Settings), plus Launcher and Settings
- **Launcher** — press the global hotkey (configurable in Settings → General); type to search everything, or Tab to cycle through the actions grid and back to search; ↑↓ to navigate results, ←→↑↓ in the grid, Return to select, Esc steps back (category → actions grid → close), Cmd+, to open Settings, Cmd+1..6 to jump to a category
- **Clipboard History** — press the clipboard hotkey (configurable in Settings → Window) to open the Launcher on the Clipboard tab, or get there via the actions grid / search; type to filter the full history and select to paste into the frontmost app
- **Settings** — sidebar navigation: General, Window, Commands, Shortcuts, Snippets, Clipboard
- **Hyper key** — enable in Settings → General, then hold Caps Lock while recording a command or shortcut hotkey; it registers as ⌃⌥⇧⌘+key and displays as `✦K`

### Settings

| Section | Contents |
| --- | --- |
| **General** | Launcher hotkey, transparency slider, Clipboard/Snippets tab toggles, snippet expansion toggle, hyper key toggle and ✦ display, export/import, launch at login, update checks, Accessibility status, URL scheme reference |
| **Window** | Clipboard History / Restore / Next Window hotkeys, action hotkeys (Center, Move Left/Right/Up/Down, Next Display), edge gap presets |
| **Commands** | Add, duplicate, delete, and edit window commands: name, hotkey, size, anchor, offsets, pinning, with a live preview |
| **Shortcuts** | Add shortcuts of three kinds (App, URL/Link, Folder/File), each with its own global hotkey; grouped by type |
| **Snippets** | Create text snippets with keywords and template variables; toggle individual snippets on/off; grouped by enabled/disabled |
| **Clipboard** | Monitor toggle, history size, auto-clear interval, clear history |

### URL scheme

```bash
open "trast://apply?name=Left%20Half"   # apply a saved command by name
open "trast://launcher"                 # open the launcher
open "trast://command?position=center&relativeWidth=0.5&relativeHeight=0.5"
```

`command` params: `position` (`topLeft`…`bottomRight`), `absoluteWidth`/`absoluteHeight` (points), `relativeWidth`/`relativeHeight` (fraction of the display), and `absolute`/`relativeXOffset`/`YOffset`.

## Updating

- In-app: menu bar icon → **Settings** → **General** → **Check for Updates** (or search "Check for Updates" in the Launcher)
- From source: `Scripts/update.sh` (release build → install to /Applications → relaunch)

## Releases

Releases are automated: pushing a `v*` tag (e.g. `v0.4.0`) runs the GitHub
Actions workflow, which tests, builds, and attaches a signed DMG to the
release. The app's version comes from the tag.

## Icons

Drop the two source files into `Resources/` and rebuild:

| File | Purpose | Notes |
| --- | --- | --- |
| `Resources/AppIconSource.png` | App icon (Finder, Dock, Activity Monitor) | 1024x1024 PNG recommended |
| `Resources/MenuBarIcon.png` | Menu bar icon | Small monochrome PNG; rendered as a template image so it adapts to light/dark menu bars |

```bash
Scripts/make_icons.sh   # AppIconSource.png → Resources/AppIcon.icns
Scripts/update.sh
```

## How it works

- The usable area is the screen's `visibleFrame` inset by the edge gap; the anchor pins the window to it, offsets shift the frame, and % sizes are relative to that area
- Windows are moved and resized through the macOS Accessibility API (`AXUIElement`)
- The Launcher is a borderless, non-activating `NSPanel` that stays floating across all spaces; it captures the frontmost window on open so window commands target the right app
- Clipboard history polls `NSPasteboard.general.changeCount` every 0.5s and stores items in a versioned JSON file
- Snippet expansion uses a listen-only `CGEvent` tap to detect keywords and injects expansion text via `CGEvent`. Template variables (`{{date}}`, `{{clipboard}}`, `{{time}}`) are resolved before injection
- The hyper key remaps Caps Lock to F18 at the HID driver level (`hidutil`, so the lock state and LED stay off), detects press/release via IOKit HID, and rewrites session events to carry ⌃⌥⇧⌘ while held — so shortcut recorders and hotkey matching see the full combo in any app
- Commands persist in `~/Library/Application Support/Trast/commands.json`; app/URL/folder shortcuts in `appShortcuts.json`; clipboard history in `clipboard.json`; snippets in `snippets.json`

## Development

```bash
swift build                  # debug build
swift run TrastTests    # test harness
Scripts/dev.sh               # debug build + relaunch app
Scripts/package_app.sh       # release build + .app bundle
```

Built with Swift Package Manager only — no Xcode project needed. See [AGENTS.md](AGENTS.md) for architecture notes and platform gotchas, and [ROADMAP.md](ROADMAP.md) for planned features.

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- Command set inspired by [Raycast's window management](https://manual.raycast.com/window-management)
