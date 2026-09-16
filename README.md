# WindowPane

Window management and a Spotlight-like launcher for macOS.

Resize and move the focused window into any layout you define — halves, thirds, sixths, or custom percentages with offsets — and trigger your presets with global hotkeys, the Launcher, or a URL. The Launcher also searches and launches installed apps, manages clipboard history, and expands text snippets.

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

- **Spotlight-style launcher** — press a global hotkey to open a search bar; results appear below as you type, grouped into Commands, Actions, Shortcuts, Applications, and WindowPane sections
- **App launching** — search and launch any installed app from the Launcher, with real app icons
- **Clipboard history** — a searchable overlay of recent clipboard items (text, images, files); select to paste into the frontmost app; pin items to keep them
- **Snippet expansion** — type a keyword anywhere on the system to expand it into predefined text; requires Input Monitoring permission
- **Launcher transparency** — adjust the panel opacity from the General settings
- **Cmd+,** — open Settings directly from the Launcher

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
cd windowpane
Scripts/package_app.sh        # release build → ./WindowPane.app
Scripts/install.sh --force    # copy to /Applications
```

Launch the app and grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility). Window control on macOS requires it. Snippet expansion additionally requires **Input Monitoring** permission (prompted on first enable).

### Stable permissions across rebuilds (recommended)

Ad-hoc–signed builds lose their Accessibility grant on every rebuild (macOS keys the grant to the binary's signature hash). Fix it once by signing with a self-signed certificate:

1. Keychain Access → **Certificate Assistant → Create a Certificate…**
2. Name: `WindowPane Dev` · Identity Type: **Self Signed Root** · Certificate Type: **Code Signing**
3. Export the identity and build:

```bash
echo 'export CODESIGN_IDENTITY="WindowPane Dev"' >> ~/.zshrc
source ~/.zshrc
Scripts/update.sh
```

Alternatively, put the certificate name in `Scripts/codesign-identity` (git-ignored) — the build script picks it up automatically.

Re-grant Accessibility one last time — after that, rebuilds keep the permission.

## Usage

- **Menu bar icon** — lists the commands you've pinned (toggle per command in Settings), plus Launcher and Settings
- **Launcher** — press the global hotkey (configurable in Settings → General); type to search commands, actions, shortcuts, installed apps, and WindowPane actions; ↑↓ to navigate, Return to select, Esc to close, Cmd+, to open Settings
- **Clipboard History** — press the clipboard hotkey (configurable in Settings → Window); search and select to paste into the frontmost app
- **Settings** — sidebar navigation: General, Window, Commands, Shortcuts, Snippets, Clipboard

### Settings

| Section | Contents |
| --- | --- |
| **General** | Launcher hotkey, transparency slider, snippet expansion toggle, export/import, launch at login, update checks, Accessibility status, URL scheme reference |
| **Window** | Clipboard History / Restore / Next Window hotkeys, action hotkeys (Center, Move Left/Right/Up/Down, Next Display), edge gap presets |
| **Commands** | Add, duplicate, delete, and edit window commands: name, hotkey, size, anchor, offsets, pinning, with a live preview |
| **Shortcuts** | Add shortcuts of three kinds (App, URL/Link, Folder/File), each with its own global hotkey; grouped by type |
| **Snippets** | Create text snippets with keywords; toggle individual snippets on/off; grouped by enabled/disabled |
| **Clipboard** | Monitor toggle, history size, auto-clear interval, clear history |

### URL scheme

```bash
open "windowpane://apply?name=Left%20Half"   # apply a saved command by name
open "windowpane://launcher"                 # open the launcher
open "windowpane://command?position=center&relativeWidth=0.5&relativeHeight=0.5"
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
- Snippet expansion uses a listen-only `CGEvent` tap to detect keywords and injects expansion text via `CGEvent`
- Commands persist in `~/Library/Application Support/WindowPane/commands.json`; app/URL/folder shortcuts in `appShortcuts.json`; clipboard history in `clipboard.json`; snippets in `snippets.json`

## Development

```bash
swift build                  # debug build
swift run WindowPaneTests    # test harness
Scripts/dev.sh               # debug build + relaunch app
Scripts/package_app.sh       # release build + .app bundle
```

Built with Swift Package Manager only — no Xcode project needed. See [AGENTS.md](AGENTS.md) for architecture notes and platform gotchas, and [ROADMAP.md](ROADMAP.md) for planned features.

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- Command set inspired by [Raycast's window management](https://manual.raycast.com/window-management)
