## Generic string-keyed LRU cache utilities.
class_name LruCacheModule
extends RefCounted

static func create_cache(max_size: int = 50) -> LruCache:
	return LruCache.new(max_size)

class LruCache extends RefCounted:
	var _cache: Dictionary = {}
	var _timestamps: Dictionary[String, int] = {}
	var _max_size: int = 50
	var _clock: int = 0

	func _init(max_size: int = 50) -> void:
		_max_size = max(1, max_size)

	func get_value(key: String) -> Variant:
		if not _cache.has(key):
			return null
		_clock += 1
		_timestamps[key] = _clock
		return _cache[key]

	func set_value(key: String, value: Variant) -> void:
		if _cache.has(key):
			_clock += 1
			_timestamps[key] = _clock
			_cache[key] = value
			return
		if _cache.size() >= _max_size:
			_evict_oldest()
		_clock += 1
		_cache[key] = value
		_timestamps[key] = _clock

	func _evict_oldest() -> void:
		var oldest_key: String = ""
		var oldest_time: int = _clock + 1
		for key in _timestamps:
			var timestamp: int = int(_timestamps[key])
			if timestamp < oldest_time:
				oldest_time = timestamp
				oldest_key = key
		if oldest_key != "":
			_cache.erase(oldest_key)
			_timestamps.erase(oldest_key)

	func has_key(key: String) -> bool:
		return _cache.has(key)

	func size() -> int:
		return _cache.size()

	func clear() -> void:
		_cache.clear()
		_timestamps.clear()
		_clock = 0
