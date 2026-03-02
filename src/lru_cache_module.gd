## Generic string-keyed LRU cache utilities.
class_name LruCacheModule
extends RefCounted

static func create_cache(max_size: int = 50) -> LruCache:
	return LruCache.new(max_size)

class LruCache extends RefCounted:
	var _cache: Dictionary = {}
	var _order: Array[String] = []
	var _max_size: int = 50

	func _init(max_size: int = 50) -> void:
		_max_size = max(1, max_size)

	func get_value(key: String) -> Variant:
		if not _cache.has(key):
			return null
		_order.erase(key)
		_order.append(key)
		return _cache[key]

	func set_value(key: String, value: Variant) -> void:
		if _cache.has(key):
			_order.erase(key)
		elif _order.size() >= _max_size:
			var oldest: String = _order.pop_front()
			_cache.erase(oldest)
		_cache[key] = value
		_order.append(key)

	func has_key(key: String) -> bool:
		return _cache.has(key)

	func size() -> int:
		return _cache.size()

	func clear() -> void:
		_cache.clear()
		_order.clear()
