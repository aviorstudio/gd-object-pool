#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
MANIFEST="${TEST_MANIFEST:-$SCRIPT_DIR/test_manifest.txt}"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Missing required test manifest: $MANIFEST" >&2
    exit 1
fi

mapfile -t tests < <(while IFS= read -r line; do
    [[ -n "$line" && "${line:0:1}" != "#" ]] && printf '%s\n' "$line"
done < "$MANIFEST")

if [[ ${#tests[@]} -eq 0 ]]; then
    echo "No tests declared in $MANIFEST" >&2
    exit 1
fi

failures=0
for relative_test in "${tests[@]}"; do
    test_path="$ROOT_DIR/$relative_test"
    if [[ ! -f "$test_path" ]]; then
        echo "Missing declared test: $relative_test" >&2
        failures=$((failures + 1))
        continue
    fi
    if ! "$SCRIPT_DIR/run_godot_test.sh" "$ROOT_DIR" "$test_path"; then
        failures=$((failures + 1))
    fi
done

if [[ $failures -ne 0 ]]; then
    echo "$failures declared test(s) failed" >&2
    exit 1
fi
echo "TEST_SUITE_REACHED ${#tests[@]}"
