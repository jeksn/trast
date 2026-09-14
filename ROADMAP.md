# Roadmap

Ideas for future improvements. Not committed to any order — pick what feels right.
This file is meant to live alongside the project and can be referenced from a landing page.

## Quick wins

_(All quick wins shipped — see the Larger features below or add new ideas here.)_

## Larger features

- **CLI tool** — a `windowpane` command-line target (`windowpane apply "Left Half"`, `windowpane list`, `windowpane picker`) that reuses `URLDispatcher` / `CommandStore`. The URL scheme works from `open` but a dedicated CLI is more ergonomic for scripts.
- **Per-display gap** — allow configuring the edge gap per display instead of a single global value.
- **Include hotkey bindings in export/import** — the current export saves command and shortcut definitions but not their hotkey assignments. Encoding `KeyboardShortcuts.getShortcut(for:)` into the export bundle would make configs fully portable.
- **Per-app command overrides** — different layouts for different apps (e.g. Safari always opens at Left Half, Terminal always at Maximize). Needs an app-bundle-ID filter on commands and a lookup path in `CommandApplier`.
- **Snap-to-grid drag overlay** — a visual overlay that snaps the dragged window to a configurable grid, as an alternative to predefined commands.
- **Bulk app import** — add multiple apps as shortcuts in one pass from the shortcut editor.
