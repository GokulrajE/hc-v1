extends Node

signal game_state_changed(new_state: String)
signal score_changed(score: int)
signal distance_changed(distance: float)
signal game_over(score: int, distance: float)

var current_state: String = "menu"
var score: int = 0
var distance: float = 0.0
var is_paused: bool = false
var game_speed: float = SCConstants.BASE_SPEED
var spawn_rate: float = SCConstants.PEDESTRIAN_SPAWN_RATE_MAX
var score_multiplier: float = 1.0
var current_phase: int = 1

func _ready() -> void:
	pass

func change_state(new_state: String) -> void:
	if current_state != new_state:
		current_state = new_state
		game_state_changed.emit(new_state)

func add_score(amount: int) -> void:
	score += int(amount * score_multiplier)
	score_changed.emit(score)

func set_distance(value: float) -> void:
	distance = value
	distance_changed.emit(int(distance))

func reset_game() -> void:
	score = 0
	distance = 0.0
	is_paused = false
	game_speed = SCConstants.BASE_SPEED
	spawn_rate = SCConstants.PEDESTRIAN_SPAWN_RATE_MAX
	score_multiplier = 1.0

func toggle_pause() -> void:
	is_paused = !is_paused

func end_game(final_score: int, final_distance: float) -> void:
	game_over.emit(final_score, final_distance)
