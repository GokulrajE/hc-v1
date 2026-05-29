class_name SCCar

extends CharacterBody2D

signal collision_detected(pedestrian: Node2D)

@export var max_speed: float = SCConstants.BASE_SPEED
@export var acceleration: float = 200.0
@export var deceleration: float = 150.0
@export var lane_change_speed: float = 300.0

var current_lane: int = 1
var target_lane: int = 1
var current_speed: float = 0.0
var _pedestrians: Array = []
var _safe_distance: float = 100.0

func _ready() -> void:
	current_lane = 1
	target_lane = 1
	current_speed = 0.0
	position = Vector2(
		SCConstants.ROAD_OFFSET_X + current_lane * SCConstants.CAR_LANE_WIDTH,
		SCConstants.SCREEN_HEIGHT - 100
	)

func _physics_process(delta: float) -> void:
	_handle_input()
	_handle_movement(delta)
	_detect_obstacles()
	_update_lane_position(delta)
	_check_collisions()
	move_and_slide()

func _handle_input() -> void:
	if Input.is_action_pressed("ui_left"):
		target_lane = max(0, target_lane - 1)
	elif Input.is_action_pressed("ui_right"):
		target_lane = min(SCConstants.CAR_LANES - 1, target_lane + 1)

func _handle_movement(delta: float) -> void:
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("w"):
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

func _exit_tree() -> void:
	_pedestrians.clear()
