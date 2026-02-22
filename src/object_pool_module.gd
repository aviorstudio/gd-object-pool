class_name ObjectPoolModule
extends RefCounted

class ObjectPoolConfig extends RefCounted:
	var max_pool_size: int
	var reset_method: String
	var reset_callable: Callable

	func _init(max_pool_size: int = 100, reset_method: String = "reset", reset_callable: Callable = Callable()) -> void:
		self.max_pool_size = max_pool_size
		self.reset_method = reset_method
		self.reset_callable = reset_callable

var _pools: Dictionary[String, Array] = {}
var _stats: Dictionary[String, Dictionary] = {}

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
			return pooled_obj

	_set_pool_size(type_key, pool.size())
	_increment_stat(type_key, "total_acquired")
	return type.new()

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
	_set_pool_size(type_key, pool.size())

func warm_pool(type: GDScript, count: int, config: ObjectPoolConfig = null) -> void:
	if count <= 0:
		return
	var resolved_config: ObjectPoolConfig = config if config else ObjectPoolConfig.new()
	var type_key: String = _get_type_key(type)
	var pool: Array = _ensure_pool(type_key)
	var remaining: int = count
	while remaining > 0 and pool.size() < resolved_config.max_pool_size:
		var pooled_obj: Object = type.new()
		_reset_object(pooled_obj, resolved_config)
		pool.append(pooled_obj)
		_increment_stat(type_key, "total_returned")
		remaining -= 1
	_set_pool_size(type_key, pool.size())

func clear_pool(type: GDScript) -> void:
	var type_key: String = _get_type_key(type)
	if _pools.has(type_key):
		_pools[type_key].clear()
	_set_pool_size(type_key, 0)

func clear_all_pools() -> void:
	for type_name in _pools.keys():
		_pools[type_name].clear()
	_pools.clear()
	_stats.clear()

func get_pool_size(type: GDScript) -> int:
	var type_key: String = _get_type_key(type)
	if not _pools.has(type_key):
		return 0
	return _pools[type_key].size()

func get_stats() -> Dictionary[String, Dictionary]:
	return _stats.duplicate(true)

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

func _reset_object(obj: Object, config: ObjectPoolConfig) -> void:
	if config.reset_callable.is_valid():
		config.reset_callable.call(obj)
		return

	if config.reset_method != "" and obj.has_method(config.reset_method):
		obj.call(config.reset_method)
