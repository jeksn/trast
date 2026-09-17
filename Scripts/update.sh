#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/Applications/Trast.app"

"$ROOT/Scripts/package_app.sh"

if pgrep -x Trast > /dev/null 2>&1; then
    pkill -x Trast || true
    sleep 0.3
fi

rm -rf "$DEST"
cp -R "$ROOT/Trast.app" "$DEST"
open "$DEST"
echo "Installed and launched $DEST"
