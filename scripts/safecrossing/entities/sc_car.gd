class_name SCCar

extends CharacterBody2D

signal collision_detected(pedestrian: Node2D)
signal traffic_collision_detected(traffic_car: Node2D)

@export var max_speed: float = SCConstants.BASE_SPEED
@export var acceleration: float = 200.0
@export var deceleration: float = 150.0
@export var lane_change_speed: float = 300.0

var current_lane: int = 1
var target_lane: int = 1
var current_speed: float = 0.0
var _pedestrians: Array = []
var _traffic_cars: Array = []
var _safe_distance: float = 100.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _original_modulate: Color

func _ready() -> void:
	current_lane = 1
	target_lane = 1
	current_speed = 0.0
	position = Vector2(
		SCConstants.ROAD_OFFSET_X + current_lane * SCConstants.CAR_LANE_WIDTH,
		SCConstants.SCREEN_HEIGHT - 100
	)
	_original_modulate = modulate

func _physics_process(delta: float) -> void:
	_handle_input()
	_handle_movement(delta)
	_detect_obstacles()
	_update_lane_position(delta)
	_check_collisions()
	_check_traffic_collisions()
	_update_blink(delta)
	move_and_slide()

func _handle_input() -> void:
	if Input.is_action_pressed("ui_left"):
		target_lane = max(0, target_lane - 1)
	elif Input.is_action_pressed("ui_right"):
		target_lane = min(SCConstants.CAR_LANES - 1, target_lane + 1)

func _handle_movement(delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, deceleration * delta)

	velocity.y = -current_speed
	velocity.x = 0.0

func _detect_obstacles() -> void:
	var car_rect = Rect2(position - Vector2(SCConstants.CAR_WIDTH / 2, SCConstants.CAR_HEIGHT / 2), Vector2(SCConstants.CAR_WIDTH, SCConstants.CAR_HEIGHT))

	for pedestrian in _pedestrians:
		if not is_instance_valid(pedestrian):
			continue

		var ped_rect = Rect2(pedestrian.position - Vector2(SCConstants.PEDESTRIAN_WIDTH / 2, SCConstants.PEDESTRIAN_HEIGHT / 2), Vector2(SCConstants.PEDESTRIAN_WIDTH, SCConstants.PEDESTRIAN_HEIGHT))

		if pedestrian.position.y < position.y and pedestrian.position.y > position.y - _safe_distance:
			var ped_lane = pedestrian.lane
			if ped_lane == target_lane:
				if target_lane > 0:
					target_lane -= 1
				elif target_lane < SCConstants.CAR_LANES - 1:
					target_lane += 1

func _update_lane_position(delta: float) -> void:
	var target_x = SCConstants.ROAD_OFFSET_X + target_lane * SCConstants.CAR_LANE_WIDTH
	var current_x = position.x

	if abs(current_x - target_x) > 1.0:
		position.x = move_toward(position.x, target_x, lane_change_speed * delta)
	else:
		position.x = target_x
		current_lane = target_lane

func _check_collisions() -> void:
	var car_rect = Rect2(position - Vector2(SCConstants.CAR_WIDTH / 2, SCConstants.CAR_HEIGHT / 2), Vector2(SCConstants.CAR_WIDTH, SCConstants.CAR_HEIGHT))

	for pedestrian in _pedestrians:
		if not is_instance_valid(pedestrian):
			continue

		var ped_rect = Rect2(pedestrian.position - Vector2(SCConstants.PEDESTRIAN_WIDTH / 2, SCConstants.PEDESTRIAN_HEIGHT / 2), Vector2(SCConstants.PEDESTRIAN_WIDTH, SCConstants.PEDESTRIAN_HEIGHT))

		if car_rect.grow(SCConstants.COLLISION_BUFFER).intersects(ped_rect):
			collision_detected.emit(pedestrian)

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

func _check_traffic_collisions() -> void:
	var car_rect = Rect2(position - Vector2(SCConstants.CAR_WIDTH / 2, SCConstants.CAR_HEIGHT / 2), Vector2(SCConstants.CAR_WIDTH, SCConstants.CAR_HEIGHT))

	for traffic_car in _traffic_cars:
		if not is_instance_valid(traffic_car):
			continue

		var traffic_rect = Rect2(traffic_car.position - Vector2(50, 50), Vector2(100, 100))

		if car_rect.grow(SCConstants.COLLISION_BUFFER).intersects(traffic_rect):
			traffic_collision_detected.emit(traffic_car)
			_start_blink()

func _start_blink() -> void:
	if _is_blinking:
		return
	_is_blinking = true
	_blink_timer = 0.5  # Blink for 0.5 seconds

func _update_blink(delta: float) -> void:
	if not _is_blinking:
		modulate = _original_modulate
		return

	_blink_timer -= delta
	if _blink_timer <= 0:
		_is_blinking = false
		modulate = _original_modulate
		return

	# Alternate color every 0.1 seconds
	var blink_interval = 0.1
	var blink_phase = fmod(_blink_timer, blink_interval * 2)
	if blink_phase < blink_interval:
		modulate = Color.RED  # Show red
	else:
		modulate = _original_modulate  # Back to original

func _exit_tree() -> void:
	_pedestrians.clear()
	_traffic_cars.clear()
