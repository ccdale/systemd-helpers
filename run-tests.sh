#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v bats >/dev/null 2>&1; then
    echo "Error: bats is not installed or not in PATH."
    echo "See TESTING.md for installation instructions."
    exit 127
fi

if [ "$#" -gt 0 ]; then
    bats "$@"
else
    bats test/systemd-helper.bats
fi
