class_name SCTrafficCar
extends Sprite2D

@export var car_type: String = "right"  # "right" = left-to-right, "left" = right-to-left
@export var min_speed: float = 100.0
@export var max_speed: float = 300.0
@export var start_x: float = 0.0
@export var rend_x: float = 2000.0
@export var lend_x: float = -80.0
@export var reset_x: float = 0.0

var current_speed: float = 0.0
var is_active: bool = false

func _ready() -> void:
	randomize()
	_initialize_car()

func _initialize_car() -> void:
	# Set starting position and random speed
	current_speed = randf_range(min_speed, max_speed)
	position.x = start_x
	is_active = true
	print("🚗 Traffic car [%s] initialized at x=%.1f with speed=%.1f" % [car_type, position.x, current_speed])

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Don't move if parent scene is not visible (scene has scrolled out of viewport)
	if get_parent() and not get_parent().visible:
		return

	match car_type:
		"right":
			# Move left to right (0 to 1000)
			position.x += current_speed * delta
			if position.x > rend_x:
				position.x = reset_x
				current_speed = randf_range(min_speed, max_speed)
				print("🚗 Right car reset to x=%.1f, new speed: %.1f" % [position.x, current_speed])

		"left":
			# Move right to left (1920 to -80)
			position.x -= current_speed * delta
			if position.x < lend_x:
				position.x = reset_x
				current_speed = randf_range(min_speed, max_speed)
				print("🚗 Left car reset to x=%.1f, new speed: %.1f" % [position.x, current_speed])

func get_car_position() -> float:
	return position.x

func stop_car() -> void:
	is_active = false

func start_car() -> void:
	is_active = true
