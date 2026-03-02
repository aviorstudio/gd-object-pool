extends SceneTree

const LruCacheModule = preload("res://src/lru_cache_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_insertion_and_lookup(failures)
	_test_eviction_at_capacity(failures)
	_test_access_promotes_recency(failures)
	_test_clear_and_size(failures)

	if failures.is_empty():
		print("PASS gd-object-pool lru_cache_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_insertion_and_lookup(failures: Array[String]) -> void:
	var cache := LruCacheModule.LruCache.new(3)
	cache.set_value("a", 1)
	cache.set_value("b", 2)
	cache.set_value("c", 3)
	if cache.size() != 3:
		failures.append("Expected size=3 after three inserts")
	if not cache.has_key("a"):
		failures.append("Expected cache to contain key 'a'")
	if int(cache.get_value("b")) != 2:
		failures.append("Expected get_value('b') to return 2")

func _test_eviction_at_capacity(failures: Array[String]) -> void:
	var cache := LruCacheModule.LruCache.new(2)
	cache.set_value("a", 1)
	cache.set_value("b", 2)
	cache.set_value("c", 3)
	if cache.size() != 2:
		failures.append("Expected size to remain capped at 2")
	if cache.has_key("a"):
		failures.append("Expected oldest key 'a' to be evicted")
	if not cache.has_key("b") or not cache.has_key("c"):
		failures.append("Expected newest keys 'b' and 'c' to remain")

func _test_access_promotes_recency(failures: Array[String]) -> void:
	var cache := LruCacheModule.LruCache.new(2)
	cache.set_value("a", 1)
	cache.set_value("b", 2)
	cache.get_value("a")
	cache.set_value("c", 3)
	if cache.has_key("b"):
		failures.append("Expected 'b' to be evicted after 'a' access promotion")
	if not cache.has_key("a") or not cache.has_key("c"):
		failures.append("Expected 'a' and 'c' to remain after promotion")

func _test_clear_and_size(failures: Array[String]) -> void:
	var cache := LruCacheModule.LruCache.new(4)
	cache.set_value("a", 1)
	cache.set_value("b", 2)
	cache.clear()
	if cache.size() != 0:
		failures.append("Expected clear() to reset size to 0")
	if cache.has_key("a") or cache.has_key("b"):
		failures.append("Expected clear() to remove all keys")
