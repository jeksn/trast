#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/Scripts/package_app.sh" debug

if pgrep -x Trast > /dev/null 2>&1; then
    pkill -x Trast || true
    sleep 0.3
fi

# Launch the executable directly instead of `open`: `open` registers the repo
# bundle in LaunchServices, and a second com.trast.app registration (dev copy
# + /Applications) makes Spotlight hide the app from search results.
nohup "$ROOT/Trast.app/Contents/MacOS/Trast" >/dev/null 2>&1 &
disown
echo "Trast launched"
