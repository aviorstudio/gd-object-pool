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

static var _pools: Dictionary[String, Array] = {}

static func get_pooled(type: GDScript, config: ObjectPoolConfig = ObjectPoolConfig.new()) -> Object:
	var type_name: String = _get_type_name(type)

	var pool: Array = _pools.get(type_name, [])
	if pool.is_empty():
		_pools[type_name] = pool

	if pool.size() > 0:
		var obj: Object = pool.pop_back()
		if obj and is_instance_valid(obj):
			_reset_object(obj, config)
			return obj

	return type.new()

static func return_to_pool(obj: Object, config: ObjectPoolConfig = ObjectPoolConfig.new()) -> void:
	if not obj or not is_instance_valid(obj):
		return

	var type_name: String = obj.get_class()

	var pool: Array = _pools.get(type_name, [])
	if pool.is_empty():
		_pools[type_name] = pool

	if pool.size() >= config.max_pool_size:
		return

	if not pool.has(obj):
		_reset_object(obj, config)
		pool.append(obj)

static func clear_pool(type: GDScript) -> void:
	var type_name: String = _get_type_name(type)

	if _pools.has(type_name):
		_pools[type_name].clear()

static func clear_all_pools() -> void:
	for type_name in _pools.keys():
		_pools[type_name].clear()
	_pools.clear()

static func get_pool_size(type: GDScript) -> int:
	var type_name: String = _get_type_name(type)

	if not _pools.has(type_name):
		return 0

	return _pools[type_name].size()

static func _get_type_name(type: GDScript) -> String:
	var instance: Object = type.new()
	var type_class_name: String = instance.get_class()
	return type_class_name

static func _reset_object(obj: Object, config: ObjectPoolConfig) -> void:
	if config.reset_callable.is_valid():
		config.reset_callable.call(obj)
		return

	if config.reset_method != "" and obj.has_method(config.reset_method):
		obj.call(config.reset_method)
