#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GODOT=${GODOT_BIN:-godot}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
archive="$work/@aviorstudio_gd-object-pool.zip"
project="$work/project"
addon_dir="$project/addons/@aviorstudio_gd-object-pool"

python3 "$ROOT_DIR/package/package.py" build "$archive"
mkdir -p "$addon_dir"
python3 - "$archive" "$addon_dir" <<'PY'
import pathlib, sys, zipfile
archive, destination = map(pathlib.Path, sys.argv[1:])
with zipfile.ZipFile(archive) as source:
    source.extractall(destination)
PY

cat > "$project/project.godot" <<'CFG'
config_version=5
[application]
config/name="gd-object-pool packaged fixture"
run/main_scene=""
[consumer]
preserve_me="owned-by-consumer"
[editor_plugins]
enabled=PackedStringArray("res://addons/@aviorstudio_gd-object-pool/plugin.cfg")
CFG
mkdir -p "$project/tests"
cat > "$project/tests/smoke.gd" <<'GD'
extends SceneTree
const Pool = preload("res://addons/@aviorstudio_gd-object-pool/src/object_pool_module.gd")
class Counter extends RefCounted:
	var value := 1
	func reset() -> void: value = 0
func _initialize() -> void:
	var pool := Pool.new()
	var config := Pool.ObjectPoolConfig.new()
	var first: Object = pool.get_pooled(Counter, config)
	pool.return_to_pool(first, Counter, config)
	var second: Object = pool.get_pooled(Counter, config)
	if first != second or second.value != 0:
		push_error("packaged smoke contract failed")
		quit(1)
		return
	print("PACKAGE_SMOKE_REACHED 1")
	quit(0)
GD

run_editor() {
    local log="$work/editor-$RANDOM.log"
    timeout --foreground 60s "$GODOT" --headless --editor --path "$project" --quit >"$log" 2>&1
    cat "$log"
    if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR:|USER ERROR:)' "$log"; then
        echo "Unexpected editor error during packaged lifecycle" >&2
        exit 1
    fi
}
run_editor
run_editor
smoke_log="$work/smoke.log"
timeout --foreground 60s "$GODOT" --headless --path "$project" --script "$project/tests/smoke.gd" >"$smoke_log" 2>&1
cat "$smoke_log"
grep -Fqx 'PACKAGE_SMOKE_REACHED 1' "$smoke_log"

python3 - "$project/project.godot" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace('enabled=PackedStringArray("res://addons/@aviorstudio_gd-object-pool/plugin.cfg")', 'enabled=PackedStringArray()')
path.write_text(text)
PY
run_editor
run_editor
grep -Fq 'preserve_me="owned-by-consumer"' "$project/project.godot"
[[ -z $(find "$project" -type l -print -quit) ]]
tree_digest=$(find "$addon_dir" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
echo "PACKAGE_INSTALL_REACHED editor-enable-restart-disable-restart tree-sha256:$tree_digest"
