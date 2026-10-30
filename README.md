<!-- Generated from private documentation source. Do not edit directly. Source SHA256: da90f0bfc49a5faee514ad2f57f2368e3563f6b0ca443e86a95b4d253d8a8d34 -->

# gd-object-pool

Reuse objects and nodes in Godot 4 instead of constantly allocating new ones.

Use this addon for bullets, cards, temporary effects, data containers, or any object type that benefits from predictable reuse.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-object-pool`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-object-pool/` and enable the plugin.

## Quick Start

```gdscript
const ObjectPoolModule = preload("res://addons/@aviorstudio_gd-object-pool/src/object_pool_module.gd")

var pool := ObjectPoolModule.new()
var config := ObjectPoolModule.ObjectPoolConfig.new(100, "reset", Callable())

var obj: Object = pool.get_pooled(MyPooledThing, config)
# Use obj...
pool.return_to_pool(obj, MyPooledThing, config)
```

## Reset Your Objects

Pooled objects should be clean every time they are checked out. Use one of these reset strategies:

- Add a method matching `ObjectPoolConfig.reset_method`, which defaults to `reset`.
- Or pass `ObjectPoolConfig.reset_callable` to reset instances externally.

```gdscript
class_name BulletData

var damage := 0
var target_id := ""

func reset() -> void:
	damage = 0
	target_id = ""
```

## What You Get

- `get_pooled`: acquire a reused or newly-created object.
- `return_to_pool`: return an object for reuse.
- `warm_pool`: pre-allocate objects before gameplay starts.
- `get_stats`: inspect created, reused, returned, and disposed counts.
- `dispose_callable`: customize cleanup when a pool is full.
- `clear_pool`: dispose/release idle entries while preserving lifetime stats.
- `clear_all_pools`: dispose/release every idle entry and reset all stats.

## Notes

- No project settings are required.
- Node instances are queued for free when they cannot be retained.
- Keep ownership rules in your game code so pooled nodes are removed from the scene tree before returning them.
- The pool owns idle entries only. Clearing never disposes checked-out objects;
  returning an object checked out before a clear disposes it with the policy
  active at that clear rather than repopulating the new pool generation.


## License

See `LICENSE`.

## Contributor checks

Install [mise](https://mise.jdx.dev/), then prepare the pinned development helpers and run the complete native gate:

```sh
git clone https://github.com/nicodes/tools.git .ci-tools
git -C .ci-tools checkout --detach f7e243524ce2aa29f299e4c79db33001f72f4a30
mise install
mise run check
```

`mise.toml` owns tool versions and tasks. Engine and template downloads are checksum verified. `mise run build` packages the addon; `mise run test` runs its declared tests. The complete check also validates the installed artifact. Build and test receipts stay in `.artifacts/verification`.
