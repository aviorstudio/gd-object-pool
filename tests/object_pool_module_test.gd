extends SceneTree

const ObjectPoolModule = preload("res://src/object_pool_module.gd")
const PooledCounter = preload("res://tests/fixtures/pooled_counter.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_repeated_get_pooled_same_type_only_allocates_once_per_type_lookup(failures)

	if failures.is_empty():
		print("PASS gd-object-pool object_pool_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_repeated_get_pooled_same_type_only_allocates_once_per_type_lookup(failures: Array[String]) -> void:
	PooledCounter.init_count = 0
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()

	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable())
	var first: RefCounted = pool.get_pooled(PooledCounter, config)
	pool.return_to_pool(first, config)
	var second: RefCounted = pool.get_pooled(PooledCounter, config)

	if PooledCounter.init_count != 2:
		failures.append("Expected exactly 2 instantiations (1 pooled object + 1 cached type-name lookup), got %d" % PooledCounter.init_count)
	if first != second:
		failures.append("Expected second get_pooled call to return pooled instance")
