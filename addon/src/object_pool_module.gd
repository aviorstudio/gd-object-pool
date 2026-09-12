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
	## Optional callable invoked for valid objects rejected because the pool is full.
	var dispose_callable: Callable

	func _init(
		max_pool_size: int = 100,
		reset_method: String = "reset",
		reset_callable: Callable = Callable(),
		factory: Callable = Callable(),
		metrics_recorder: Callable = Callable(),
		dispose_callable: Callable = Callable()
	) -> void:
		self.max_pool_size = max_pool_size
		self.reset_method = reset_method
		self.reset_callable = reset_callable
		self.factory = factory
		self.metrics_recorder = metrics_recorder
		self.dispose_callable = dispose_callable

var _pools: Dictionary[String, Array] = {}
var _pool_ids: Dictionary[String, Dictionary] = {}
var _stats: Dictionary[String, Dictionary] = {}
var _configs: Dictionary[String, ObjectPoolConfig] = {}
var _generations: Dictionary[String, int] = {}
var _checked_out: Dictionary[String, Dictionary] = {}
var _retired_dispose_configs: Dictionary[String, Dictionary] = {}

## Returns true when the given type supports the configured reset contract.
static func validate_poolable(type: GDScript, config: ObjectPoolConfig) -> bool:
	var probe: Object = type.new()
	if probe == null:
		return false
	var has_reset: bool = config.reset_callable.is_valid() or (
		config.reset_method != "" and probe.has_method(config.reset_method)
	)
	if probe is RefCounted:
		probe = null
	else:
		probe.free()
	return has_reset

## Returns an object instance for the given script type.
## Reuses pooled instances when available, otherwise creates a new one.
func get_pooled(type: GDScript, config: ObjectPoolConfig = null) -> Object:
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	var type_key: String = _get_type_key(type)
	_remember_config(type_key, resolved_config)
	var pool: Array = _ensure_pool(type_key)
	var pool_ids: Dictionary = _ensure_pool_ids(type_key)
	_purge_invalid_ids(pool_ids)
	while not pool.is_empty():
		var pooled_obj: Variant = pool.pop_back()
		if is_instance_valid(pooled_obj):
			pool_ids.erase(pooled_obj.get_instance_id())
			_reset_object(pooled_obj, resolved_config)
			_set_pool_size(type_key, pool.size())
			_increment_stat(type_key, "total_acquired")
			_record_metric(resolved_config, type_key, "pool_acquired", 1)
			_track_checkout(type_key, pooled_obj)
			return pooled_obj

	_set_pool_size(type_key, pool.size())
	_increment_stat(type_key, "total_acquired")
	_increment_stat(type_key, "total_created")
	_record_metric(resolved_config, type_key, "pool_acquired", 1)
	_record_metric(resolved_config, type_key, "pool_created", 1)
	var created: Object = _create_instance(type, resolved_config)
	if created and is_instance_valid(created):
		_track_checkout(type_key, created)
	return created

## Returns an object instance to the pool for future reuse.
func return_to_pool(obj: Object, type: GDScript, config: ObjectPoolConfig = null) -> void:
	if not obj or not is_instance_valid(obj):
		return
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	var type_key: String = _get_type_key(type)
	_remember_config(type_key, resolved_config)
	var instance_id: int = obj.get_instance_id()
	var checkout_generation: int = _take_checkout_generation(type_key, instance_id)
	var current_generation: int = _ensure_generation(type_key)
	if checkout_generation >= 0 and checkout_generation < current_generation:
		var retired_config: ObjectPoolConfig = _get_retired_config(type_key, checkout_generation, resolved_config)
		_dispose_and_record(type_key, obj, retired_config)
		_release_retired_config_if_unused(type_key, checkout_generation)
		return
	var pool: Array = _ensure_pool(type_key)
	var pool_ids: Dictionary = _ensure_pool_ids(type_key)
	if pool_ids.has(instance_id):
		_set_pool_size(type_key, pool.size())
		return
	if pool.size() >= resolved_config.max_pool_size:
		_set_pool_size(type_key, pool.size())
		_dispose_and_record(type_key, obj, resolved_config)
		return

	_reset_object(obj, resolved_config)
	pool.append(obj)
	pool_ids[instance_id] = true
	_increment_stat(type_key, "total_returned")
	_record_metric(resolved_config, type_key, "pool_returned", 1)
	_set_pool_size(type_key, pool.size())

## Pre-allocates pooled objects for a script type.
func warm_pool(type: GDScript, count: int, config: ObjectPoolConfig = null) -> void:
	if count <= 0:
		return
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	if not validate_poolable(type, resolved_config):
		push_warning("ObjectPoolModule: type %s has no reset method '%s'" % [type.resource_path, resolved_config.reset_method])
	var type_key: String = _get_type_key(type)
	_remember_config(type_key, resolved_config)
	var pool: Array = _ensure_pool(type_key)
	var pool_ids: Dictionary = _ensure_pool_ids(type_key)
	var remaining: int = count
	while remaining > 0 and pool.size() < resolved_config.max_pool_size:
		var pooled_obj: Object = _create_instance(type, resolved_config)
		_increment_stat(type_key, "total_created")
		_reset_object(pooled_obj, resolved_config)
		pool.append(pooled_obj)
		pool_ids[pooled_obj.get_instance_id()] = true
		_increment_stat(type_key, "total_returned")
		remaining -= 1
	_set_pool_size(type_key, pool.size())

## Disposes/releases all idle instances for one script type. Lifetime stats are
## preserved and checked-out instances are never disposed. Objects checked out
## before this call are disposed by this generation's policy if returned later.
func clear_pool(type: GDScript) -> void:
	var type_key: String = _get_type_key(type)
	var generation: int = _ensure_generation(type_key)
	var config: ObjectPoolConfig = _configs.get(type_key, ObjectPoolConfig.new())
	_purge_invalid_checkouts(type_key)
	if _has_checkout_generation(type_key, generation):
		_ensure_retired_configs(type_key)[generation] = config
	if _pools.has(type_key):
		for pooled_obj: Variant in _pools[type_key]:
			if is_instance_valid(pooled_obj):
				_dispose_and_record(type_key, pooled_obj, config)
		_pools[type_key].clear()
	if _pool_ids.has(type_key):
		_pool_ids[type_key].clear()
	_set_pool_size(type_key, 0)
	_generations[type_key] = generation + 1

## Clears all pools and all tracked stats.
func clear_all_pools() -> void:
	for type_name: String in _pools.keys():
		var generation: int = _ensure_generation(type_name)
		var config: ObjectPoolConfig = _configs.get(type_name, ObjectPoolConfig.new())
		_purge_invalid_checkouts(type_name)
		if _has_checkout_generation(type_name, generation):
			_ensure_retired_configs(type_name)[generation] = config
		for pooled_obj: Variant in _pools[type_name]:
			if is_instance_valid(pooled_obj):
				_dispose_and_record(type_name, pooled_obj, config)
		_generations[type_name] = generation + 1
	_pools.clear()
	_pool_ids.clear()
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
## `{ "pool_size": int, "acquired": int, "returned": int, "created": int,
## "disposed": int }`.
func get_pool_stats(type: GDScript) -> Dictionary:
	var type_key: String = _get_type_key(type)
	_ensure_stats(type_key)
	var entry: Dictionary = _stats[type_key]
	return {
		"pool_size": int(entry.get("pool_size", 0)),
		"acquired": int(entry.get("total_acquired", 0)),
		"returned": int(entry.get("total_returned", 0)),
		"created": int(entry.get("total_created", 0)),
		"disposed": int(entry.get("total_disposed", 0)),
	}

func _get_type_key(type: GDScript) -> String:
	return type.resource_path

func _ensure_pool(type_key: String) -> Array:
	if not _pools.has(type_key):
		var new_pool: Array[Object] = []
		_pools[type_key] = new_pool
	_ensure_pool_ids(type_key)
	_ensure_stats(type_key)
	return _pools[type_key]

func _ensure_pool_ids(type_key: String) -> Dictionary:
	if not _pool_ids.has(type_key):
		var new_pool_ids: Dictionary[int, bool] = {}
		_pool_ids[type_key] = new_pool_ids
	return _pool_ids[type_key]

func _ensure_stats(type_key: String) -> void:
	if _stats.has(type_key):
		return
	var new_stats: Dictionary[String, int] = {
		"pool_size": 0,
		"total_acquired": 0,
		"total_returned": 0,
		"total_created": 0,
		"total_disposed": 0,
	}
	_stats[type_key] = new_stats

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

func _dispose_object(obj: Object, config: ObjectPoolConfig) -> void:
	if not obj or not is_instance_valid(obj):
		return
	if config.dispose_callable.is_valid():
		config.dispose_callable.call(obj)
		return
	if obj is Node:
		(obj as Node).queue_free()
	elif not (obj is RefCounted):
		obj.free()

func _dispose_and_record(type_key: String, obj: Object, config: ObjectPoolConfig) -> void:
	_dispose_object(obj, config)
	_increment_stat(type_key, "total_disposed")
	_record_metric(config, type_key, "pool_disposed", 1)

func _remember_config(type_key: String, config: ObjectPoolConfig) -> void:
	_configs[type_key] = config
	_ensure_generation(type_key)
	_ensure_checked_out(type_key)
	_ensure_retired_configs(type_key)

func _ensure_generation(type_key: String) -> int:
	if not _generations.has(type_key):
		_generations[type_key] = 0
	return _generations[type_key]

func _ensure_checked_out(type_key: String) -> Dictionary:
	if not _checked_out.has(type_key):
		var entries: Dictionary[int, int] = {}
		_checked_out[type_key] = entries
	return _checked_out[type_key]

func _ensure_retired_configs(type_key: String) -> Dictionary:
	if not _retired_dispose_configs.has(type_key):
		var entries: Dictionary[int, ObjectPoolConfig] = {}
		_retired_dispose_configs[type_key] = entries
	return _retired_dispose_configs[type_key]

func _track_checkout(type_key: String, obj: Object) -> void:
	_ensure_checked_out(type_key)[obj.get_instance_id()] = _ensure_generation(type_key)

func _take_checkout_generation(type_key: String, instance_id: int) -> int:
	var entries: Dictionary = _ensure_checked_out(type_key)
	if not entries.has(instance_id):
		return -1
	var generation: int = int(entries[instance_id])
	entries.erase(instance_id)
	return generation

func _get_retired_config(type_key: String, generation: int, fallback: ObjectPoolConfig) -> ObjectPoolConfig:
	var entries: Dictionary = _ensure_retired_configs(type_key)
	return entries.get(generation, fallback)

func _has_checkout_generation(type_key: String, generation: int) -> bool:
	for tracked_generation: Variant in _ensure_checked_out(type_key).values():
		if int(tracked_generation) == generation:
			return true
	return false

func _release_retired_config_if_unused(type_key: String, generation: int) -> void:
	if not _has_checkout_generation(type_key, generation):
		_ensure_retired_configs(type_key).erase(generation)

func _purge_invalid_checkouts(type_key: String) -> void:
	var entries: Dictionary = _ensure_checked_out(type_key)
	for instance_id: int in entries.keys():
		if not is_instance_id_valid(instance_id):
			entries.erase(instance_id)

func _purge_invalid_ids(entries: Dictionary) -> void:
	for instance_id: int in entries.keys():
		if not is_instance_id_valid(instance_id):
			entries.erase(instance_id)
