#!/usr/bin/env bash
set -euo pipefail

# Start fun-bots-helper (fun-bots-helper/src/fun-bots-helper.py)
# Usage: ./start-fun-bots-helper.sh [args...]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to activate local .venv if present
if [ -d "$ROOT_DIR/.venv" ]; then
    ACTIVATE="$ROOT_DIR/.venv/bin/activate"
    if [ -f "$ACTIVATE" ]; then
        # shellcheck source=/dev/null
        source "$ACTIVATE"
        echo "Using virtualenv: $ROOT_DIR/.venv"
    else
        echo "Warning: .venv found but activate script missing at $ACTIVATE" >&2
    fi
fi

SCRIPT="$ROOT_DIR/fun-bots-helper/src/fun-bots-helper.py"
if [ ! -f "$SCRIPT" ]; then
    echo "Error: helper script not found: $SCRIPT" >&2
    exit 1
fi

python "$SCRIPT" "$@"
