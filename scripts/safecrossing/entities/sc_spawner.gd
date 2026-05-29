class_name SCSpawner

extends Node

signal pedestrian_requested

@export var spawn_rate: float = SCConstants.PEDESTRIAN_SPAWN_RATE_MAX

var _spawn_timer: float = 0.0
var _is_spawning: bool = true

func _ready() -> void:
	_spawn_timer = spawn_rate
	_is_spawning = true

func _process(delta: float) -> void:
	if not _is_spawning:
		return

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		pedestrian_requested.emit()
		_spawn_timer = spawn_rate

func stop_spawning() -> void:
	_is_spawning = false

func resume_spawning() -> void:
	_is_spawning = true
	_spawn_timer = spawn_rate

func start_spawning() -> void:
	_is_spawning = true
	_spawn_timer = spawn_rate

func clear_pedestrians() -> void:
	pass
