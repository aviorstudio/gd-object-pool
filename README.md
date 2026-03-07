# gd-object-pool

Object pooling primitives for Godot 4 with configurable reset behavior.

This addon is intentionally limited to pooling/reset mechanics.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-object-pool`

### Manual
Copy this directory into `addons/@aviorstudio_gd-object-pool/` and enable the plugin.

## Quick Start

```gdscript
const ObjectPoolModule = preload("res://addons/@aviorstudio_gd-object-pool/src/object_pool_module.gd")

var pool := ObjectPoolModule.new()
var config := ObjectPoolModule.ObjectPoolConfig.new(100, "reset", Callable())
var obj: Object = pool.get_pooled(MyScript, config)
pool.return_to_pool(obj, MyScript, config)
```

## API Reference

- `ObjectPoolConfig`: max size and reset hooks.
- `get_pooled` / `return_to_pool`: acquire and release pooled objects.
- `warm_pool`: pre-allocate instances.
- `get_stats`: inspect pool utilization counters.

## Poolable Protocol

Pooled types should support one reset strategy so each acquired instance is clean:

- Implement a method matching `ObjectPoolConfig.reset_method` (default: `reset`).
- Or provide `ObjectPoolConfig.reset_callable` to reset instances externally.

`ObjectPoolModule.validate_poolable(type, config)` checks this contract, and `warm_pool(...)`
logs a warning when the configured reset strategy is missing.

## Scope Boundary

- In scope: object reuse, pool limits, and reset contracts.
- Out of scope: app lifecycle ownership, scene orchestration, and domain-specific cache policy.

## Configuration

No project settings are required.

## Testing

`./tests/test.sh`

## License

MIT
