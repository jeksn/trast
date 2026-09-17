#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/Scripts/package_app.sh" debug

if pgrep -x Trast > /dev/null 2>&1; then
    pkill -x Trast || true
    sleep 0.3
fi

open "$ROOT/Trast.app"
echo "Trast launched"
