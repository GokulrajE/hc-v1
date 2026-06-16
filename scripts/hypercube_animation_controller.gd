extends AnimatedSprite2D

## Animation properties
const ROTATION_SPEED: float = 1.0
const BOB_SPEED: float = 2.0
const BOB_AMOUNT: float = 20.0

var original_position: Vector2

func _ready() -> void:
	original_position = position
	play()

func _process(delta: float) -> void:
	# Continuous smooth rotation
	rotation += ROTATION_SPEED * delta

	# Bobbing motion (vertical movement)
	var bob = sin(get_tree().get_frame() * BOB_SPEED * 0.01) * BOB_AMOUNT
	position.y = original_position.y + bob
