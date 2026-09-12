#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/tests"

run_control() {
    local name=$1 expected=$2
    local manifest="$fixture/$name.manifest"
    printf 'tests/%s.gd\n' "$name" > "$manifest"
    if TEST_MANIFEST="$manifest" GODOT_TEST_TIMEOUT_SECONDS=2 "$SCRIPT_DIR/test.sh" >/dev/null 2>&1; then
        actual=pass
    else
        actual=fail
    fi
    if [[ "$actual" != "$expected" ]]; then
        echo "Control $name expected $expected, got $actual" >&2
        exit 1
    fi
    echo "CONTROL_REACHED $name $actual"
}

cat > "$fixture/tests/success.gd" <<'GD'
extends SceneTree
func _initialize() -> void:
	print("TEST_REACHED success 1")
	print("PASS gd-object-pool success")
	quit(0)
GD
cat > "$fixture/tests/runtime_error.gd" <<'GD'
extends SceneTree
func _initialize() -> void:
	push_error("deliberate runtime error control")
	print("TEST_REACHED runtime_error 1")
	print("PASS gd-object-pool runtime_error")
	quit(0)
GD
cat > "$fixture/tests/overwritten_failure.gd" <<'GD'
extends SceneTree
func _initialize() -> void:
	print("TEST_REACHED overwritten_failure 1")
	quit(1)
	quit(0)
GD
cat > "$fixture/tests/parse_failure.gd" <<'GD'
extends SceneTree
func _initialize() -> void
	print("unreachable")
GD
cat > "$fixture/tests/hang.gd" <<'GD'
extends SceneTree
func _initialize() -> void:
	pass
GD

# The runner project root is normally the repository. Copy controls there only
# for each invocation so their deliberate errors can never enter the real suite.
for name in success runtime_error overwritten_failure parse_failure hang; do
    cp "$fixture/tests/$name.gd" "$SCRIPT_DIR/$name.gd"
    trap 'rm -rf "$fixture"; rm -f "$SCRIPT_DIR"/{success,runtime_error,overwritten_failure,parse_failure,hang}.gd' EXIT
done

run_control success pass
run_control runtime_error fail
run_control overwritten_failure fail
run_control parse_failure fail
run_control hang fail

printf 'tests/does_not_exist.gd\n' > "$fixture/missing.manifest"
if TEST_MANIFEST="$fixture/missing.manifest" "$SCRIPT_DIR/test.sh" >/dev/null 2>&1; then
    echo "Missing-script control unexpectedly passed" >&2
    exit 1
fi
echo "CONTROL_REACHED missing_script fail"

rm -f "$SCRIPT_DIR"/{success,runtime_error,overwritten_failure,parse_failure,hang}.gd
echo "GATE_CONTROLS_RESTORED 6"
