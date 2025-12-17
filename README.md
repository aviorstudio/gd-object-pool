# gd-object-pool

Simple object pooling helper with configurable reset hooks for Godot 4.

## Usage
- Preload: `const ObjectPoolModule = preload("res://addons/@your_addon_dir/src/object_pool_module.gd")`
- Configure: `var pool_config := ObjectPoolModule.ObjectPoolConfig.new(max_size, "reset", Callable())`
- Get instances: `var instance := ObjectPoolModule.get_pooled(MyScript, pool_config)`
- Return instances: `ObjectPoolModule.return_to_pool(instance, pool_config)`
- Maintenance: `ObjectPoolModule.clear_pool(MyScript)` or `clear_all_pools()`; query with `get_pool_size(MyScript)`.

## Notes
- `reset_callable` runs first if provided; otherwise the module invokes `reset_method` when returning objects.
- Pools are keyed by class name; ensure pooled types expose a reset routine to avoid leaking state.
