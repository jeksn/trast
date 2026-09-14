# Roadmap

Ideas for future improvements. Not committed to any order — pick what feels right.
This file is meant to live alongside the project and can be referenced from a landing page.

## Quick wins

- **Fuzzy match highlighting** — bold matched characters in picker rows. `FuzzyMatch` already returns scores; tracking matched indices and rendering them bold is a small view-layer change.
- **Recently-used ordering in the picker** — on an empty query, sort by last-invoked timestamp instead of insertion order. Needs a small `[UUID: Date]` usage log persisted alongside the stores.
- **"Test" button in editors** — try a command or app shortcut without closing the editor sheet.
- **Quick preset buttons in the command editor** — one-tap starting points (Left Half, Maximize, Center) that set width/height/anchor in a single click.
- **Auto-check for updates on launch** — `UpdateChecker` exists but is manual-only. A toggle in General settings + a silent background check would close the gap.
- **App shortcuts in the menu bar** — currently only window commands can be pinned. A submenu for app/URL/folder shortcuts would make them mouse-reachable.
- **"Next Window" in the menu bar** — it has a hotkey but no menu item, unlike Restore and Quick Picker.
- **Hover-to-highlight in the picker** — mouse hover highlights the row under the cursor, not just keyboard-driven selection.
- **Menu bar key equivalents** — show hotkey shortcuts next to pinned commands in the menu bar dropdown.

## Larger features

- **CLI tool** — a `windowpane` command-line target (`windowpane apply "Left Half"`, `windowpane list`, `windowpane picker`) that reuses `URLDispatcher` / `CommandStore`. The URL scheme works from `open` but a dedicated CLI is more ergonomic for scripts.
- **Per-display gap** — allow configuring the edge gap per display instead of a single global value.
- **Include hotkey bindings in export/import** — the current export saves command and shortcut definitions but not their hotkey assignments. Encoding `KeyboardShortcuts.getShortcut(for:)` into the export bundle would make configs fully portable.
- **Per-app command overrides** — different layouts for different apps (e.g. Safari always opens at Left Half, Terminal always at Maximize). Needs an app-bundle-ID filter on commands and a lookup path in `CommandApplier`.
- **Snap-to-grid drag overlay** — a visual overlay that snaps the dragged window to a configurable grid, as an alternative to predefined commands.
- **Bulk app import** — add multiple apps as shortcuts in one pass from the shortcut editor.
