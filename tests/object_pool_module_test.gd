extends SceneTree

const ObjectPoolModule = preload("res://src/object_pool_module.gd")
const PooledCounter = preload("res://tests/fixtures/pooled_counter.gd")
const PooledCounterAlt = preload("res://tests/fixtures/pooled_counter_alt.gd")
const NonResettableCounter = preload("res://tests/fixtures/non_resettable_counter.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_repeated_get_pooled_same_type_reuses_instance(failures)
	_test_script_resource_path_keying_keeps_pools_separate(failures)
	_test_warm_pool_and_stats(failures)
	_test_validate_poolable_contract(failures)
	_test_factory_pool_stats_and_clear_pool(failures)
	_test_metrics_recorder_callback(failures)

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

	var pooled_counter_script: Script = PooledCounter
	var key: String = pooled_counter_script.resource_path
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

func _test_validate_poolable_contract(failures: Array[String]) -> void:
	var with_reset_config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable())
	if not ObjectPoolModule.validate_poolable(PooledCounter, with_reset_config):
		failures.append("Expected PooledCounter to satisfy reset-method poolable contract")

	var without_reset_config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable())
	if ObjectPoolModule.validate_poolable(NonResettableCounter, without_reset_config):
		failures.append("Expected NonResettableCounter to fail reset-method poolable contract")

	var callable_config := ObjectPoolModule.ObjectPoolConfig.new(10, "", func(_obj: Object) -> void: pass)
	if not ObjectPoolModule.validate_poolable(NonResettableCounter, callable_config):
		failures.append("Expected reset callable to satisfy poolable contract")

func _test_factory_pool_stats_and_clear_pool(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()

	var factory_config := ObjectPoolModule.ObjectPoolConfig.new(
		10,
		"",
		Callable(),
		Callable(self, "_factory_create")
	)

	var created: RefCounted = pool.get_pooled(PooledCounter, factory_config)
	if created == null:
		failures.append("Expected factory-backed get_pooled to create an object")

	pool.return_to_pool(created, PooledCounter, factory_config)
	var stats: Dictionary = pool.get_pool_stats(PooledCounter)
	if int(stats.get("created", -1)) != 1:
		failures.append("Expected get_pool_stats created=1")
	if int(stats.get("acquired", -1)) != 1:
		failures.append("Expected get_pool_stats acquired=1")
	if int(stats.get("returned", -1)) != 1:
		failures.append("Expected get_pool_stats returned=1")
	if int(stats.get("pool_size", -1)) != 1:
		failures.append("Expected get_pool_stats pool_size=1")

	pool.clear_pool(PooledCounter)
	if pool.get_pool_size(PooledCounter) != 0:
		failures.append("Expected clear_pool to remove pooled instances for type")

func _test_metrics_recorder_callback(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()
	var metric_calls: Array[Dictionary] = []
	var metrics_recorder: Callable = func(pool_type: String, metric_name: String, value: int) -> void:
		metric_calls.append({"pool_type": pool_type, "metric_name": metric_name, "value": value})
	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset", Callable(), Callable(), metrics_recorder)

	var first: RefCounted = pool.get_pooled(PooledCounter, config)
	pool.return_to_pool(first, PooledCounter, config)
	pool.get_pooled(PooledCounter, config)

	var pooled_counter_script: Script = PooledCounter
	var key: String = pooled_counter_script.resource_path
	var expected_calls: Array[Dictionary] = [
		{"pool_type": key, "metric_name": "pool_acquired", "value": 1},
		{"pool_type": key, "metric_name": "pool_created", "value": 1},
		{"pool_type": key, "metric_name": "pool_returned", "value": 1},
		{"pool_type": key, "metric_name": "pool_acquired", "value": 1},
	]
	if metric_calls.size() != expected_calls.size():
		failures.append("Expected %d metric calls, got %d" % [expected_calls.size(), metric_calls.size()])
		return
	for index in range(expected_calls.size()):
		var actual: Dictionary = metric_calls[index]
		var expected: Dictionary = expected_calls[index]
		if str(actual.get("pool_type", "")) != str(expected.get("pool_type", "")):
			failures.append("Expected metric call %d pool_type=%s, got %s" % [index, expected.get("pool_type", ""), actual.get("pool_type", "")])
		if str(actual.get("metric_name", "")) != str(expected.get("metric_name", "")):
			failures.append("Expected metric call %d metric_name=%s, got %s" % [index, expected.get("metric_name", ""), actual.get("metric_name", "")])
		if int(actual.get("value", -1)) != int(expected.get("value", -1)):
			failures.append("Expected metric call %d value=%d, got %d" % [index, int(expected.get("value", -1)), int(actual.get("value", -1))])

func _factory_create(type: GDScript) -> Object:
	return type.new()
