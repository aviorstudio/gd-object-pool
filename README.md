# gd-object-pool

Object pooling primitives for Godot 4 with configurable reset behavior.

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

## Configuration

No project settings are required.

## Testing

`./tests/test.sh`

## License

MIT
