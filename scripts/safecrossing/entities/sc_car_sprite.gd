class_name SCCarSprite
extends Sprite2D

signal collision_detected(pedestrian: Node2D)
signal traffic_collision_detected(traffic_car: Node2D)

@export var max_speed: float = 300.0
@export var acceleration: float = 200.0
@export var deceleration: float = 150.0

var current_speed: float = 0.0
var _pedestrians: Array = []
var _traffic_cars: Array = []
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _original_modulate: Color

func _ready() -> void:
	_original_modulate = modulate

func _process(delta: float) -> void:
	_check_collisions()
	_update_blink(delta)

func _check_collisions() -> void:
	var car_rect = Rect2(global_position - Vector2(40, 40), Vector2(80, 80))

	# Check pedestrian collisions
	for pedestrian in _pedestrians:
		if not is_instance_valid(pedestrian):
			continue
		var ped_rect = Rect2(pedestrian.global_position - Vector2(30, 30), Vector2(60, 60))
		if car_rect.intersects(ped_rect):
			print("💥 COLLISION: Car at %s, Pedestrian at %s" % [global_position, pedestrian.global_position])
			collision_detected.emit(pedestrian)
			_start_blink()

	# Check traffic car collisions
	for traffic_car in _traffic_cars:
		if not is_instance_valid(traffic_car):
			continue
		var traffic_rect = Rect2(traffic_car.global_position - Vector2(50, 50), Vector2(100, 100))
		if car_rect.intersects(traffic_rect):
			print("💥 COLLISION: Car at %s, Traffic at %s" % [global_position, traffic_car.global_position])
			traffic_collision_detected.emit(traffic_car)
			_start_blink()

func add_pedestrian(pedestrian: Node2D) -> void:
	if pedestrian not in _pedestrians:
		_pedestrians.append(pedestrian)

func remove_pedestrian(pedestrian: Node2D) -> void:
	_pedestrians.erase(pedestrian)

func add_traffic_car(traffic_car: Node2D) -> void:
	if traffic_car not in _traffic_cars:
		_traffic_cars.append(traffic_car)

func remove_traffic_car(traffic_car: Node2D) -> void:
	_traffic_cars.erase(traffic_car)

func _start_blink() -> void:
	if _is_blinking:
		return
	_is_blinking = true
	_blink_timer = 0.5

func _update_blink(delta: float) -> void:
	if not _is_blinking:
		modulate = _original_modulate
		return

	_blink_timer -= delta
	if _blink_timer <= 0:
		_is_blinking = false
		modulate = _original_modulate
		return

	# Blink red
	var blink_interval = 0.1
	var blink_phase = fmod(_blink_timer, blink_interval * 2)
	if blink_phase < blink_interval:
		modulate = Color.RED
	else:
		modulate = _original_modulate

func _find_pedestrians() -> void:
	# Find all pedestrian characters in the scene
	var all_characters = get_tree().get_nodes_in_group("pedestrian")
	if all_characters.is_empty():
		# Fallback: search for SCCharacter nodes by class name
		for child in get_tree().root.get_children():
			_search_for_characters(child)
	else:
		for character in all_characters:
			add_pedestrian(character)
	print("🚶 Found %d pedestrians" % _pedestrians.size())

func _search_for_characters(node: Node) -> void:
	if node is AnimatedSprite2D and node.get_script() and "SCCharacter" in node.get_script().resource_path:
		add_pedestrian(node)
	for child in node.get_children():
		_search_for_characters(child)

func _find_traffic_cars() -> void:
	# Find all traffic cars in the scene
	var all_traffic = get_tree().get_nodes_in_group("traffic_car")
	for traffic_car in all_traffic:
		add_traffic_car(traffic_car)
	print("🚗 Found %d traffic cars" % _traffic_cars.size())
