extends SceneTree

const ObjectPoolModule = preload("res://addon/src/object_pool_module.gd")
const PooledCounter = preload("res://tests/fixtures/pooled_counter.gd")
const PooledCounterAlt = preload("res://tests/fixtures/pooled_counter_alt.gd")
const NonResettableCounter = preload("res://tests/fixtures/non_resettable_counter.gd")
const PooledNode = preload("res://tests/fixtures/pooled_node.gd")
const ManualPooledObject = preload("res://tests/fixtures/manual_pooled_object.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_repeated_get_pooled_same_type_reuses_instance(failures)
	_test_script_resource_path_keying_keeps_pools_separate(failures)
	_test_warm_pool_and_stats(failures)
	_test_validate_poolable_contract(failures)
	_test_factory_pool_stats_and_clear_pool(failures)
	_test_metrics_recorder_callback(failures)
	_test_duplicate_return_is_ignored_before_capacity(failures)
	await _test_clear_ownership_and_late_returns(failures)
	_test_refcounted_and_custom_disposal(failures)
	_test_invalid_and_repeated_clear(failures)
	await _test_clear_all_disposes_idle_and_resets_stats(failures)

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

func _test_duplicate_return_is_ignored_before_capacity(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	pool.clear_all_pools()
	var disposed_objects: Array[Object] = []
	var dispose_callable: Callable = func(_obj: Object) -> void:
		disposed_objects.append(_obj)
	var config := ObjectPoolModule.ObjectPoolConfig.new(1, "reset", Callable(), Callable(), Callable(), dispose_callable)

	var first: RefCounted = pool.get_pooled(PooledCounter, config)
	pool.return_to_pool(first, PooledCounter, config)
	pool.return_to_pool(first, PooledCounter, config)

	if pool.get_pool_size(PooledCounter) != 1:
		failures.append("Expected duplicate return to keep pool size at 1")
	var stats: Dictionary = pool.get_pool_stats(PooledCounter)
	if int(stats.get("returned", -1)) != 1:
		failures.append("Expected duplicate return not to increment returned stats")
	if disposed_objects.size() != 0:
		failures.append("Expected duplicate return not to dispose pooled object")

	var second := PooledCounter.new()
	pool.return_to_pool(second, PooledCounter, config)
	if disposed_objects.size() != 1:
		failures.append("Expected full pool to dispose a distinct returned object")

func _factory_create(type: GDScript) -> Object:
	return type.new()

func _test_clear_ownership_and_late_returns(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset")
	pool.warm_pool(PooledNode, 2, config)
	var checked_out: Node = pool.get_pooled(PooledNode, config)
	var checked_out_id := checked_out.get_instance_id()
	pool.clear_pool(PooledNode)
	await process_frame
	await process_frame
	if not is_instance_id_valid(checked_out_id):
		failures.append("clear_pool disposed a checked-out Node")
	if pool.get_pool_size(PooledNode) != 0:
		failures.append("clear_pool retained an idle Node")
	var stats := pool.get_pool_stats(PooledNode)
	if int(stats.get("created", -1)) != 2 or int(stats.get("disposed", -1)) != 1:
		failures.append("clear_pool must preserve counters and record one idle disposal")
	pool.return_to_pool(checked_out, PooledNode, config)
	await process_frame
	await process_frame
	if is_instance_id_valid(checked_out_id):
		failures.append("pre-clear late Node return was not disposed")
	if pool.get_pool_size(PooledNode) != 0:
		failures.append("pre-clear late return repopulated the pool")
	var orphan_final := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphan_final != 0:
		failures.append("Node clear lifecycle retained owned orphans: %d" % orphan_final)

func _test_refcounted_and_custom_disposal(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	var ref_config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset")
	pool.warm_pool(PooledCounter, 2, ref_config)
	pool.clear_pool(PooledCounter)
	if pool.get_pool_size(PooledCounter) != 0 or int(pool.get_pool_stats(PooledCounter).get("disposed", -1)) != 2:
		failures.append("clear_pool did not release both idle RefCounted entries")

	var disposed_ids: Array[int] = []
	var custom_config := ObjectPoolModule.ObjectPoolConfig.new(
		10, "reset", Callable(), Callable(), Callable(),
		func(obj: Object) -> void: disposed_ids.append(obj.get_instance_id())
	)
	pool.warm_pool(ManualPooledObject, 2, custom_config)
	pool.clear_pool(ManualPooledObject)
	if disposed_ids.size() != 2:
		failures.append("clear_pool did not route idle manual objects through the custom disposer")
	# Custom disposal owns lifetime; release the controls manually after observing it.
	for instance_id in disposed_ids:
		var instance := instance_from_id(instance_id)
		if instance and is_instance_valid(instance):
			instance.free()

	var old_disposed: Array[int] = []
	var new_disposed: Array[int] = []
	var old_config := ObjectPoolModule.ObjectPoolConfig.new(
		10, "reset", Callable(), Callable(), Callable(),
		func(obj: Object) -> void:
			old_disposed.append(obj.get_instance_id())
			obj.free()
	)
	var new_config := ObjectPoolModule.ObjectPoolConfig.new(
		10, "reset", Callable(), Callable(), Callable(),
		func(obj: Object) -> void:
			new_disposed.append(obj.get_instance_id())
			obj.free()
	)
	var checked_out: Object = pool.get_pooled(ManualPooledObject, old_config)
	pool.clear_pool(ManualPooledObject)
	pool.return_to_pool(checked_out, ManualPooledObject, new_config)
	if old_disposed.size() != 1 or not new_disposed.is_empty():
		failures.append("late return did not use the disposal policy active at clear")

func _test_invalid_and_repeated_clear(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset")
	var manual: Object = pool.get_pooled(ManualPooledObject, config)
	pool.return_to_pool(manual, ManualPooledObject, config)
	manual.free()
	pool.clear_pool(ManualPooledObject)
	pool.clear_pool(ManualPooledObject)
	if pool.get_pool_size(ManualPooledObject) != 0:
		failures.append("repeated clear retained an invalid manual object")
	if int(pool.get_pool_stats(ManualPooledObject).get("disposed", -1)) != 0:
		failures.append("invalid idle instance was counted as disposed")

func _test_clear_all_disposes_idle_and_resets_stats(failures: Array[String]) -> void:
	var pool := ObjectPoolModule.new()
	var config := ObjectPoolModule.ObjectPoolConfig.new(10, "reset")
	pool.warm_pool(PooledNode, 1, config)
	pool.warm_pool(PooledCounter, 1, config)
	pool.clear_all_pools()
	await process_frame
	await process_frame
	if not pool.get_stats().is_empty():
		failures.append("clear_all_pools did not reset all stats")
	if pool.get_pool_size(PooledNode) != 0 or pool.get_pool_size(PooledCounter) != 0:
		failures.append("clear_all_pools retained idle entries")
	var orphan_final := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphan_final != 0:
		failures.append("clear_all_pools retained owned Node orphans: %d" % orphan_final)
