class_name SCCharacter

extends AnimatedSprite2D

@export var speed: float = 80.0  # Walking speed
@export var crossing_y: float = 476.0  # Fixed Y position on crossing line
@export var start_x: float = 430.0  # Starting X position (left edge of road)

var _walking_left: bool = false  # Direction
var _is_active: bool = false

func _ready() -> void:
	print("✅ Character _ready() called")
	print("  Position before: ", position)
	print("  Scale before: ", scale)
	print("  Visible: ", visible)
	print("  SpriteFrames set: ", sprite_frames != null)
	start_x = position.x
	if sprite_frames == null:
		print("❌ ERROR: SpriteFrames not set in editor!")
		return

	# Start animation using the "default" animation from editor
	play("default")
	print("  Animation playing: ", is_playing())

	# Position on crossing line
	position = Vector2(position.x, position.y)
	visible = true
	print("✅ Character positioned at: ", position)
	print("✅ Scale: ", scale)
	print("✅ Now visible: ", visible)

	_is_active = true

func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	# Keep fixed on crossing line
	position.y = crossing_y

	# Move horizontally
	if _walking_left:
		position.x -= speed * delta
		scale.x = -1.5  # Face left
	else:
		position.x += speed * delta
		scale.x = 1.5  # Face right

	# Reset when off-screen (allow full traversal across 1920px screen)
	if position.x > 1500:
		position.x = start_x

func set_direction(is_left: bool) -> void:
	_walking_left = is_left
	if is_left:
		scale.x = -1.5
	else:
		scale.x = 1.5

func stop_walking() -> void:
	_is_active = false

func reset_position() -> void:
	position = Vector2(start_x, crossing_y)
	_is_active = true
	print("✅ Character reset to starting position: ", position)
