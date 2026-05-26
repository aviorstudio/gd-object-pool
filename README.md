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

## Notes

- No project settings are required.
- Node instances are queued for free when they cannot be retained.
- Keep ownership rules in your game code so pooled nodes are removed from the scene tree before returning them.

## Testing

`./tests/test.sh`

## License

MIT
