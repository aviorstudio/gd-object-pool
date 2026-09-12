#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 PROJECT_ROOT TEST_SCRIPT" >&2
    exit 2
fi

root=$1
test_script=$2
godot=${GODOT_BIN:-godot}
timeout_seconds=${GODOT_TEST_TIMEOUT_SECONDS:-60}
name=$(basename "$test_script" .gd)
log=$(mktemp)
trap 'rm -f "$log"' EXIT

echo "Running $name..."
status=0
timeout --foreground "${timeout_seconds}s" "$godot" --headless --path "$root" --script "$test_script" >"$log" 2>&1 || status=$?
cat "$log"

if [[ $status -eq 124 ]]; then
    echo "Timed out after ${timeout_seconds}s: $name" >&2
    exit 1
fi
if [[ $status -ne 0 ]]; then
    echo "Godot exited $status: $name" >&2
    exit 1
fi
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR:|USER ERROR:)' "$log"; then
    echo "Unexpected Godot error output: $name" >&2
    exit 1
fi
if [[ $(grep -Fxc "PASS gd-object-pool $name" "$log") -ne 1 ]]; then
    echo "Required PASS marker missing or duplicated: $name" >&2
    exit 1
fi
echo "TEST_REACHED $name 1"
