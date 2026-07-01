extends Node2D

func _ready():
	var viewport_size = get_viewport_rect().size
	position = Vector2(viewport_size.x / 2, viewport_size.y / 2)

func _draw():
	var viewport_size = get_viewport_rect().size
	var width = viewport_size.x
	var height = viewport_size.y

	# Background is now handled by sprite, but keep subtle overlay
	# No need to draw gradient if background image is in place
