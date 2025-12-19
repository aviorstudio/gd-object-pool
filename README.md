# gd-object-pool

Game-agnostic object pooling helper for Godot 4 with configurable reset hooks.

- Package: `@aviorstudio/gd-object-pool`
- Godot: `4.x` (tested on `4.4`)

## Install

Place this folder under `res://addons/<addon-dir>/` (for example `res://addons/@aviorstudio_gd-object-pool/`).

- With `gdpm`: install/link into your project's `addons/`.
- Manually: copy or symlink this repo folder into `res://addons/<addon-dir>/`.

## Files

- `plugin.cfg` / `plugin.gd`: editor plugin entry (no runtime behavior).
- `src/object_pool_module.gd`: pooling implementation (also registers `class_name ObjectPoolModule`).

## Usage

```gdscript
const ObjectPool = preload("res://addons/<addon-dir>/src/object_pool_module.gd")

var config := ObjectPool.ObjectPoolConfig.new(100, "reset", Callable())

var obj := ObjectPool.get_pooled(MyScript, config)
# ...
ObjectPool.return_to_pool(obj, config)
```

## Configuration

None.

## Notes

- `reset_callable` runs first if provided; otherwise the module invokes `reset_method` on return.
- Pools are keyed by `Object.get_class()`; use `class_name` on pooled scripts if you need unique pools per script.
