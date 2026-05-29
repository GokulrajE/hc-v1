class_name SCObjectPool

extends Node

var _pool: Dictionary = {}
var _available: Dictionary = {}

func _init() -> void:
	pass

func initialize_pool(object_name: String, scene_path: String, pool_size: int) -> void:
	var scene = load(scene_path)
	if not scene:
		push_error("Failed to load scene: %s" % scene_path)
		return

	_pool[object_name] = []
	_available[object_name] = []

	for i in range(pool_size):
		var instance = scene.instantiate()
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		_pool[object_name].append(instance)
		_available[object_name].append(instance)

func get_object(object_name: String) -> Node:
	if object_name not in _available or _available[object_name].is_empty():
		push_warning("Object pool empty for: %s" % object_name)
		return null

	var obj = _available[object_name].pop_back()
	obj.visible = true
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	return obj

func return_object(object_name: String, obj: Node) -> void:
	if object_name not in _available:
		return

	obj.visible = false
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	_available[object_name].append(obj)

func get_pool_info(object_name: String) -> Dictionary:
	if object_name not in _pool:
		return {}

	return {
		"total": _pool[object_name].size(),
		"available": _available[object_name].size(),
		"in_use": _pool[object_name].size() - _available[object_name].size()
	}

func add_to_scene(object_name: String, parent: Node) -> void:
	if object_name not in _pool:
		return

	for obj in _pool[object_name]:
		parent.add_child(obj)

func clear_all() -> void:
	_pool.clear()
	_available.clear()
