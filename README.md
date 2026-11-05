<!-- Generated from private documentation source. Do not edit directly. Source SHA256: 20fcc410f955a996b62afa72c74195df38c9c170c422000b683f0cfe762a3eb8 -->

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

Install [mise](https://mise.jdx.dev/) and GNU Make, then run:

```sh
make setup
make build
make test
```

`mise.toml` pins SDK versions. `cookbook.toml` declares the addon package and its real tests; the generated Make entrypoint uses an exact shared cookbook revision from `nicodes/tools`. Setup installs the pinned editor, export templates and applicable dependencies. Build creates and verifies the closed addon archive; tests run source checks, native assertions, security checks and the declared packaged integration or browser checks. Packaged tests require the current verified build. Test commands do not run setup or rebuild the addon.

`make help` lists the available commands. Use `make test:lint`, `make test:unit`, `make test:integration` or `make test:security` for an individual group, `make fmt` for formatting, and `make clean` for declared generated files. Build and test evidence stays in `.artifacts/verification`.
