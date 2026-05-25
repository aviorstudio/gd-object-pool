## Generic string-keyed LRU cache utilities.
class_name LruCacheModule
extends RefCounted

static func create_cache(max_size: int = 50) -> LruCache:
	return LruCache.new(max_size)

class LruCache extends RefCounted:
	var _cache: Dictionary[String, Variant] = {}
	var _order: Array[String] = []
	var _max_size: int = 50

	func _init(max_size: int = 50) -> void:
		_max_size = max(1, max_size)

	func get_value(key: String) -> Variant:
		if not _cache.has(key):
			return null
		_promote(key)
		return _cache[key]

	func set_value(key: String, value: Variant) -> void:
		if _cache.has(key):
			_cache[key] = value
			_promote(key)
			return
		if _cache.size() >= _max_size:
			_evict_oldest()
		_cache[key] = value
		_order.append(key)

	func _promote(key: String) -> void:
		var idx: int = _order.find(key)
		if idx >= 0:
			_order.remove_at(idx)
		_order.append(key)

	func _evict_oldest() -> void:
		if _order.is_empty():
			return
		var oldest_key: String = _order.pop_front()
		_cache.erase(oldest_key)

	func has_key(key: String) -> bool:
		return _cache.has(key)

	func size() -> int:
		return _cache.size()

	func clear() -> void:
		_cache.clear()
		_order.clear()
