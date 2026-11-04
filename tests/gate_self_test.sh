#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/tests"

run_control() {
    local name=$1 expected=$2
    if python3 "$TOOLS_ROOT/helpers/godot-test.py" --project "$SCRIPT_DIR/.." --program "$fixture/tests/$name.gd" --sentinel "PASS gd-object-pool $name" --timeout 2 >/dev/null 2>&1; then
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

run_control success pass
run_control runtime_error fail
run_control overwritten_failure fail
run_control parse_failure fail
run_control hang fail

if python3 "$TOOLS_ROOT/helpers/godot-test.py" --project "$SCRIPT_DIR/.." --program "$fixture/tests/does_not_exist.gd" --sentinel NEVER --timeout 2 >/dev/null 2>&1; then
    echo "Missing-script control unexpectedly passed" >&2
    exit 1
fi
echo "CONTROL_REACHED missing_script fail"

echo "GATE_CONTROLS_RESTORED 6"
