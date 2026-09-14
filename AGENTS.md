# WindowPane

macOS menu-bar utility that applies user-defined window sizes/positions to the focused window (Raycast "Create Command" style). Native Swift 6 + SwiftUI, built with Swift Package Manager only — no Xcode project, works with Command Line Tools.

## Commands

```bash
swift build                  # debug build (app + tests)
swift run WindowPaneTests    # run the test harness (exits non-zero on failure)
Scripts/package_app.sh       # release build + WindowPane.app bundle (version from latest git tag)
Scripts/dev.sh               # debug build + bundle + relaunch app
Scripts/update.sh            # release build + install to /Applications + relaunch
Scripts/make_dmg.sh          # release build + drag-to-Applications DMG in dist/
Scripts/install.sh [--force] # copy WindowPane.app to /Applications
```

There is no `swift test` workflow: this machine has Command Line Tools only (no full Xcode). CLT ships neither XCTest nor a working Swift Testing runtime (test bundles build but the runner discovers zero tests), so tests live in the `WindowPaneTests` executable target and run via `swift run WindowPaneTests`.

## Layout

- `Sources/WindowPaneCore/` — dependency-free logic: `WindowDimension`, `Anchor` (two-axis struct with per-axis `keep` for move-style commands; decodes legacy flat strings like `"topLeft"`), `WindowCommand` (+ `seeds`, + `migratingLegacyCommands`), `LayoutEngine` (pure frame math + `frameForNextDisplay` for multi-display moves), `FuzzyMatch`, `WindowPaneURL` parsing, `AppSettings`. All public API — consumed by both the app and tests.
- `Sources/WindowPane/` — app target: AX layer (`Accessibility`, `WindowManipulator`), `CommandApplier` (+ `RestoreStore`; intercepts the `nextDisplay` action before the normal LayoutEngine path to cycle `NSScreen.screens`), `CommandStore` (versioned JSON at `~/Library/Application Support/WindowPane/commands.json`; v2 = `{version, commands}`, legacy bare arrays migrate via `WindowCommand.migratingLegacyCommands`, which preserves IDs of name-matched commands so hotkeys survive), `AppShortcutStore` (versioned JSON at `~/Library/Application Support/WindowPane/appShortcuts.json`; `AppShortcut.Kind` = `app`, `url`, or `folder`), `ConfigPorter` (export/import combined JSON of both stores), `HotkeyManager`, menu bar + settings UI, `PickerController`/`PickerView` (Spotlight-style overlay; items grouped into Commands / Actions / Shortcuts sections), `HUD` feedback, `URLDispatcher`.
- Commands carry `isDefault` (seeds; sidebar "Defaults" section, restorable via `restoreDefaults()`) and `showInMenuBar` (menu bar only lists pinned commands; toggle in the editor, indicator in the sidebar). New custom commands are pinned by default.
- **CI**: `.github/workflows/release.yml` builds/tests/DMGs on `v*` tag push and attaches the DMG to a GitHub Release. CI imports the signing certificate from repo secrets (`MACOS_SIGNING_P12` = base64 p12, `MACOS_SIGNING_PASSWORD` = export password) and signs with the stable identity — without the secrets it falls back to ad-hoc, which resets the Accessibility grant on update.
- **SPM resource bundles in packaged apps**: dependency packages with resources (KeyboardShortcuts) get a `Bundle.module` accessor that only checks the .app ROOT (codesign rejects placing bundles there) and an absolute path baked at build time. `package_app.sh` copies the bundles to `Contents/Resources/` and patches the baked path in the binary to `/Applications/WindowPane.app/Contents/Resources/<bundle>`, padding with path-safe slashes to preserve the baked string length (Swift literals are pointer+count, so the replacement must be same-length). Without the patch, packaged apps crash on any hotkey Recorder (Settings > General).
- **Updates**: `UpdateChecker` (app target) queries `https://api.github.com/repos/jeksn/windowpane/releases/latest` — **update the `repo` constant when the GitHub repo is created/renamed**. Compares via `VersionCompare` (Core), offers download-and-install (DMG asset → hdiutil → copy to /Applications → relaunch) or opening the release page. Bundle version comes from the latest git tag (`package_app.sh`), so tag releases `vX.Y.Z`.
- `Tests/WindowPaneTests/` — custom harness (`TestRunner` + suite files + `main.swift`).

## Notes / gotchas

- **KeyboardShortcuts is pinned to exactly 1.10.0.** Newer 3.x uses SwiftUI `@Entry`/`#Preview` macros whose plugin dylibs (`SwiftUIMacros`, `PreviewsMacros`) do not ship with CLT — builds fail. Also, this environment's GitHub mirror only exposes tags up to v1.10.0.
- `onKeyUp` handlers APPEND (never replace): each command registers exactly once per UUID (`HotkeyManager.registeredCommandIDs`); handlers resolve the command dynamically from the store at fire time, so stale registrations are harmless no-ops. Deleting a command clears its shortcut via `KeyboardShortcuts.setShortcut(nil, for:)`.
- Offset semantics match Raycast: positive X offset moves right, **positive Y offset moves DOWN** (screen convention; the engine subtracts in Cocoa's bottom-left coordinates). Percent sizes/anchors/offsets are relative to `visibleFrame` inset by the global edge gap.
- `AppDelegate` registers the `windowpane://` URL scheme via `NSAppleEventManager` kAEGetURL. The event class/ID and direct-object keyword are hard-coded FourCharCode literals (`0x4755524C` = 'GURL', `0x2D2D2D2D` = '----') to avoid Carbon import issues with CLT.
- `WindowManipulator` uses the private `_AXUIElementGetWindow` (dlsym'd from ApplicationServices) to key restore geometry by CGWindowID; falls back to `pid-title` keys. Same approach as Rectangle/Loop.
- AX coordinates are top-left origin, NSScreen bottom-left; conversion helpers live in `WindowManipulator` (primary screen height based).
- Settings is a custom `Window` scene (id `settings`), not the SwiftUI `Settings` scene — the `showSettingsWindow:` selector is unreliable in menu-bar apps on newer macOS. `MenuContent.openSettingsWindow()` activates the app, calls `openWindow(id:)`, then re-activates and orders the window front.
- The picker panel is `.nonactivatingPanel` so the target app stays frontmost; the target window is captured when the panel opens.
- **Next Window hotkey** (`GeneralSettingsView` / `HotkeyManager.nextWindow`): `WindowCycler` uses Accessibility to get the front app's windows, find the current main window, and raise the next one, so it works regardless of whether the system "Move focus to next window" shortcut is enabled or what keyboard layout is in use.
- **Next Display action** (`WindowAction.nextDisplay`, id `"nextDisplay"`): unlike other actions that flow through `LayoutEngine.frame(for:)` on a single screen, this one is intercepted in `CommandApplier.apply` (checked by `command.id == WindowAction.nextDisplay.commandID`) and handled by `moveToNextDisplay`, which finds the current screen via `WindowManipulator.screen(containing:)`, cycles to the next in `NSScreen.screens`, and uses `LayoutEngine.frameForNextDisplay` to preserve the window's relative position and size. The pure math is testable in `LayoutEngineTests`.
- **Export / Import** (`ConfigPorter`, app target): combines `CommandStore.commands` and `AppShortcutStore.shortcuts` into a single versioned JSON. Import calls `replace(with:)` on both stores, which clears old hotkey bindings and re-registers. Hotkey assignments themselves are not included (stored by KeyboardShortcuts in UserDefaults, keyed by `KeyboardShortcuts.Name`).
- App icon: drop a 1024x1024 PNG at `Resources/AppIconSource.png`, run `Scripts/make_icons.sh` (sips + iconutil generate `Resources/AppIcon.icns`), then rebuild — `package_app.sh` embeds it and sets `CFBundleIconFile`.
- Menu bar icon: drop a small monochrome (template-style) PNG at `Resources/MenuBarIcon.png`; `package_app.sh` bundles it and `StatusBarIcon` loads it at runtime (rendered as a template image, 18pt tall, falling back to the `rectangle.split.3x3` SF Symbol when absent).
- **Signing**: `package_app.sh` resolves the identity in order: `CODESIGN_IDENTITY` env → `Scripts/codesign-identity` file (git-ignored, first line) → ad-hoc. Ad-hoc signatures change on every rebuild and invalidate the Accessibility (TCC) grant — with a stable identity (self-signed "WindowPane Dev" cert) the grant survives rebuilds. Fix per rebuild otherwise: `tccutil reset Accessibility com.windowpane.app`, re-toggle, relaunch.
- Opening System Settings panes uses `/usr/bin/open` via `Process` (`Accessibility.openSystemSettings()`), trying `x-apple.systemsettings:` then the legacy `x-apple.systempreferences:` scheme (this macOS build only registers the legacy one), then falls back to launching System Settings by bundle ID. `NSWorkspace.shared.open` fails to resolve these schemes when the app is launched from a terminal session.
