extends RefCounted

static var init_count: int = 0
var was_reset: bool = false

func _init() -> void:
	init_count += 1

func reset() -> void:
	was_reset = true
