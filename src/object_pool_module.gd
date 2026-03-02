## Generic keyed object pools with optional reset hooks and usage stats.
##
## Example:
## var pool := ObjectPoolModule.new()
## var config := ObjectPoolModule.ObjectPoolConfig.new(100, "reset", Callable(), Callable())
## var obj: Object = pool.get_pooled(MyType, config)
## pool.return_to_pool(obj, MyType, config)
class_name ObjectPoolModule
extends RefCounted

## Pool configuration for max size and object reset strategy.
class ObjectPoolConfig extends RefCounted:
	## Maximum number of instances retained for a type.
	var max_pool_size: int
	## Optional method name invoked to reset an instance before pooling/reuse.
	var reset_method: String
	## Optional reset callable invoked with the object instance.
	var reset_callable: Callable
	## Optional object factory callable. When set, called as `factory.call(type)`.
	var factory: Callable
	## Optional callable invoked as `recorder.call(pool_type, metric_name, value)`.
	var metrics_recorder: Callable

	func _init(
		max_pool_size: int = 100,
		reset_method: String = "reset",
		reset_callable: Callable = Callable(),
		factory: Callable = Callable(),
		metrics_recorder: Callable = Callable()
	) -> void:
		self.max_pool_size = max_pool_size
		self.reset_method = reset_method
		self.reset_callable = reset_callable
		self.factory = factory
		self.metrics_recorder = metrics_recorder

var _pools: Dictionary[String, Array] = {}
var _stats: Dictionary[String, Dictionary] = {}

## Returns an object instance for the given script type.
## Reuses pooled instances when available, otherwise creates a new one.
func get_pooled(type: GDScript, config: ObjectPoolConfig = null) -> Object:
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	var type_key: String = _get_type_key(type)
	var pool: Array = _ensure_pool(type_key)
	while not pool.is_empty():
		var pooled_obj: Object = pool.pop_back()
		if pooled_obj and is_instance_valid(pooled_obj):
			_reset_object(pooled_obj, resolved_config)
			_set_pool_size(type_key, pool.size())
			_increment_stat(type_key, "total_acquired")
			_record_metric(resolved_config, type_key, "pool_acquired", 1)
			return pooled_obj

	_set_pool_size(type_key, pool.size())
	_increment_stat(type_key, "total_acquired")
	_increment_stat(type_key, "total_created")
	_record_metric(resolved_config, type_key, "pool_acquired", 1)
	_record_metric(resolved_config, type_key, "pool_created", 1)
	return _create_instance(type, resolved_config)

## Returns an object instance to the pool for future reuse.
func return_to_pool(obj: Object, type: GDScript, config: ObjectPoolConfig = null) -> void:
	if not obj or not is_instance_valid(obj):
		return
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	var type_key: String = _get_type_key(type)
	var pool: Array = _ensure_pool(type_key)
	if pool.size() >= resolved_config.max_pool_size:
		_set_pool_size(type_key, pool.size())
		return

	if not pool.has(obj):
		_reset_object(obj, resolved_config)
		pool.append(obj)
		_increment_stat(type_key, "total_returned")
		_record_metric(resolved_config, type_key, "pool_returned", 1)
	_set_pool_size(type_key, pool.size())

## Pre-allocates pooled objects for a script type.
func warm_pool(type: GDScript, count: int, config: ObjectPoolConfig = null) -> void:
	if count <= 0:
		return
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	var type_key: String = _get_type_key(type)
	var pool: Array = _ensure_pool(type_key)
	var remaining: int = count
	while remaining > 0 and pool.size() < resolved_config.max_pool_size:
		var pooled_obj: Object = _create_instance(type, resolved_config)
		_increment_stat(type_key, "total_created")
		_reset_object(pooled_obj, resolved_config)
		pool.append(pooled_obj)
		_increment_stat(type_key, "total_returned")
		remaining -= 1
	_set_pool_size(type_key, pool.size())

## Clears all pooled instances for one script type.
func clear_pool(type: GDScript) -> void:
	var type_key: String = _get_type_key(type)
	if _pools.has(type_key):
		_pools[type_key].clear()
	_set_pool_size(type_key, 0)

## Clears all pools and all tracked stats.
func clear_all_pools() -> void:
	for type_name in _pools.keys():
		_pools[type_name].clear()
	_pools.clear()
	_stats.clear()

## Returns current pooled instance count for one script type.
func get_pool_size(type: GDScript) -> int:
	var type_key: String = _get_type_key(type)
	if not _pools.has(type_key):
		return 0
	return _pools[type_key].size()

## Returns all internal pool stats keyed by script resource path.
func get_stats() -> Dictionary[String, Dictionary]:
	return _stats.duplicate(true)

## Returns pool stats for a script type.
##
## The dictionary format is:
## `{ "pool_size": int, "acquired": int, "returned": int, "created": int }`.
func get_pool_stats(type: GDScript) -> Dictionary:
	var type_key: String = _get_type_key(type)
	_ensure_stats(type_key)
	var entry: Dictionary = _stats[type_key]
	return {
		"pool_size": int(entry.get("pool_size", 0)),
		"acquired": int(entry.get("total_acquired", 0)),
		"returned": int(entry.get("total_returned", 0)),
		"created": int(entry.get("total_created", 0)),
	}

func _get_type_key(type: GDScript) -> String:
	return type.resource_path

func _ensure_pool(type_key: String) -> Array:
	if not _pools.has(type_key):
		_pools[type_key] = []
	_ensure_stats(type_key)
	return _pools[type_key]

func _ensure_stats(type_key: String) -> void:
	if _stats.has(type_key):
		return
	_stats[type_key] = {
		"pool_size": 0,
		"total_acquired": 0,
		"total_returned": 0,
		"total_created": 0,
	}

func _increment_stat(type_key: String, field_name: String) -> void:
	_ensure_stats(type_key)
	var entry: Dictionary = _stats[type_key]
	entry[field_name] = int(entry.get(field_name, 0)) + 1
	_stats[type_key] = entry

func _set_pool_size(type_key: String, size: int) -> void:
	_ensure_stats(type_key)
	var entry: Dictionary = _stats[type_key]
	entry["pool_size"] = size
	_stats[type_key] = entry

func _record_metric(config: ObjectPoolConfig, type_key: String, metric_name: String, value: int) -> void:
	if config == null:
		return
	if not config.metrics_recorder.is_valid():
		return
	config.metrics_recorder.call(type_key, metric_name, value)

func _create_instance(type: GDScript, config: ObjectPoolConfig) -> Object:
	if config.factory.is_valid():
		var produced: Variant = config.factory.call(type)
		if produced is Object:
			return produced
	return type.new()

func _reset_object(obj: Object, config: ObjectPoolConfig) -> void:
	if config.reset_callable.is_valid():
		config.reset_callable.call(obj)
		return

	if config.reset_method != "" and obj.has_method(config.reset_method):
		obj.call(config.reset_method)
