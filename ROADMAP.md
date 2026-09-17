# Roadmap

Ideas for future improvements. Not committed to any order — pick what feels right.
This file is meant to live alongside the project and can be referenced from a landing page.

## Quick wins

_(All quick wins shipped — see the Larger features below or add new ideas here.)_

## Larger features

- **CLI tool** — a `trast` command-line target (`trast apply "Left Half"`, `trast list`, `trast picker`) that reuses `URLDispatcher` / `CommandStore`. The URL scheme works from `open` but a dedicated CLI is more ergonomic for scripts.
- **Per-display gap** — allow configuring the edge gap per display instead of a single global value.
- **Include hotkey bindings in export/import** — the current export saves command and shortcut definitions but not their hotkey assignments. Encoding `KeyboardShortcuts.getShortcut(for:)` into the export bundle would make configs fully portable.
- **Per-app command overrides** — different layouts for different apps (e.g. Safari always opens at Left Half, Terminal always at Maximize). Needs an app-bundle-ID filter on commands and a lookup path in `CommandApplier`.
- **Snap-to-grid drag overlay** — a visual overlay that snaps the dragged window to a configurable grid, as an alternative to predefined commands.
- **Bulk app import** — add multiple apps as shortcuts in one pass from the shortcut editor.

## Licensing & monetization

- **14-day trial + license key** — offline Ed25519 license validation via CryptoKit. 14-day full trial, then locked. $5 one-time via Paddle list fulfillment. See `MONETIZATION.md` and `MONETIZATION_PLAN.md` (git-ignored) for details.
- **LicenseTool CLI** — developer-only tool for generating Ed25519 key pairs, single keys, and batch .txt files for Paddle upload.
- **License settings tab** — trial status, license key entry, "Buy Trast" link to Paddle checkout.

## Marketing & launch

- **Landing page** — one-screen: headline, gif, features, $5 one-time, download + buy buttons, comparison vs Rectangle/Magnet, FAQ.
- **Screen recording** — 15-30 second gif of the picker in action.
- **Staged rollout** — warm network first, then niche communities (r/macapps, r/macsetups), then broader launch (Product Hunt, HN Show HN). See `GO_TO_MARKET.md` (git-ignored) for the full plan.
