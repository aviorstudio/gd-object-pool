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

## Repository Layout

- `addon/`: Godot plugin source packaged for GDAM and manual installation.
- `addon/plugin.cfg`: plugin name, version, description, and entry script.
- `addon/src/`: reusable GDScript modules.
- `tests/`: Godot test project/scripts for addon behavior.
- `.github/workflows/ci.yml`: validates package shape and runs tests.
- `.github/workflows/release.yml`: creates GitHub release ZIPs and publishes to GDAM.

## Versioning And Releases

The version in `addon/plugin.cfg` is the addon package version. Releases are created from `main` with the manual release workflow and plain semver tags like `v0.0.1`; the workflow verifies `plugin.cfg`, builds `@aviorstudio_gd-object-pool.zip`, and publishes `@aviorstudio/gd-object-pool` to GDAM.

## Testing

**Correction (fieldsofrevik#146):** earlier CI used Godot 4.4.1 and an
exit-code-only loop, so the statement below overstated what a green run proved.
CI and release now use the same Godot 4.7.2 suite, reject runtime/log errors,
prove assertion reachability, and install the exact closed-manifest ZIP through
enable/restart/disable/restart editor lifecycle checks.

Run locally with:

```sh
./tests/test.sh
```

CI runs the required test manifest unconditionally. The addon is platform-neutral
GDScript with no browser-specific implementation path, so the supported matrix
for this release is Godot 4.7.2 on native Linux; browser verification is not
applicable to this repository.

## License

MIT
