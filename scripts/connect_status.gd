extends Sprite2D

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if HCcomm:
		if HCcomm.device_is_connected:
			modulate = Color.GREEN
		else:
			modulate = Color.RED
