class_name SCPedestrian

extends CharacterBody2D

signal out_of_bounds

@export var speed: float = SCConstants.PEDESTRIAN_SPEED
@export var crossing_y: float = 476.0  # Fixed Y position on crossing line (center of crossing in PedestriansWalk)

var lane: int = 0
var pool_owner: SCObjectPool = null
var _active: bool = false
var _crossing_direction: int = 1  # 1 for right, -1 for left

func _ready() -> void:
	_active = false

func _physics_process(delta: float) -> void:
	if not _active:
		return

	# Pedestrians are FIXED at crossing line - only horizontal movement
	# Fixed at crossing_y, only move left/right across the road
	position.y = crossing_y  # Keep fixed on crossing line

	# Move only horizontally across the road
	velocity.x = speed * _crossing_direction
	velocity.y = 0  # No vertical movement

	move_and_slide()

	# Out of bounds when pedestrian walks off the sides of road
	if position.x < 0 or position.x > 1920:
		_on_out_of_bounds()

func reset() -> void:
	_active = true
	velocity = Vector2.ZERO
	_crossing_direction = 1 if randi() % 2 == 0 else -1

func _on_out_of_bounds() -> void:
	_active = false
	out_of_bounds.emit()

	if pool_owner:
		pool_owner.return_object("pedestrian", self)

func stop() -> void:
	_active = false
	velocity = Vector2.ZERO

func _exit_tree() -> void:
	stop()
