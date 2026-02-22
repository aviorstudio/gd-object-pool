extends SceneTree

const ObjectPoolModule = preload("res://src/object_pool_module.gd")
const PooledCounter = preload("res://tests/fixtures/pooled_counter.gd")
const PooledCounterAlt = preload("res://tests/fixtures/pooled_counter_alt.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_repeated_get_pooled_same_type_reuses_instance(failures)
	_test_script_resource_path_keying_keeps_pools_separate(failures)
	_test_warm_pool_and_stats(failures)

	if failures.is_empty():
		print("PASS gd-object-pool object_pool_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_repeated_get_pooled_same_type_reuses_instance(failures: Array[String]) -> void:
	PooledCounter.init_count = 0
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()

	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable())
	var first: RefCounted = pool.get_pooled(PooledCounter, config)
	pool.return_to_pool(first, PooledCounter, config)
	var second: RefCounted = pool.get_pooled(PooledCounter, config)

	if PooledCounter.init_count != 1:
		failures.append("Expected exactly 1 instantiation for pooled reuse, got %d" % PooledCounter.init_count)
	if first != second:
		failures.append("Expected second get_pooled call to return pooled instance")

func _test_script_resource_path_keying_keeps_pools_separate(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()
	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable())

	var first_a: RefCounted = pool.get_pooled(PooledCounter, config)
	var first_b: RefCounted = pool.get_pooled(PooledCounterAlt, config)
	pool.return_to_pool(first_a, PooledCounter, config)
	pool.return_to_pool(first_b, PooledCounterAlt, config)

	if pool.get_pool_size(PooledCounter) != 1:
		failures.append("Expected PooledCounter pool size to be 1")
	if pool.get_pool_size(PooledCounterAlt) != 1:
		failures.append("Expected PooledCounterAlt pool size to be 1")

func _test_warm_pool_and_stats(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()
	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable())
	pool.warm_pool(PooledCounter, 3, config)

	if pool.get_pool_size(PooledCounter) != 3:
		failures.append("Expected warm_pool to pre-allocate 3 instances")

	var key: String = PooledCounter.resource_path
	var stats_after_warm: Dictionary[String, Dictionary] = pool.get_stats()
	if not stats_after_warm.has(key):
		failures.append("Expected stats entry for warmed type")
		return

	var warm_entry: Dictionary = stats_after_warm[key]
	if int(warm_entry.get("pool_size", -1)) != 3:
		failures.append("Expected warm stats pool_size=3")
	if int(warm_entry.get("total_acquired", -1)) != 0:
		failures.append("Expected warm stats total_acquired=0")
	if int(warm_entry.get("total_returned", -1)) != 3:
		failures.append("Expected warm stats total_returned=3")

	var acquired: RefCounted = pool.get_pooled(PooledCounter, config)
	pool.return_to_pool(acquired, PooledCounter, config)
	var stats_final: Dictionary[String, Dictionary] = pool.get_stats()
	var final_entry: Dictionary = stats_final[key]
	if int(final_entry.get("pool_size", -1)) != 3:
		failures.append("Expected final stats pool_size=3")
	if int(final_entry.get("total_acquired", -1)) != 1:
		failures.append("Expected final stats total_acquired=1")
	if int(final_entry.get("total_returned", -1)) != 4:
		failures.append("Expected final stats total_returned=4")
