extends Node

signal game_state_changed(new_state: String)
signal score_changed(score: int)
signal distance_changed(distance: float)
signal game_over(score: int, distance: float)
signal difficulty_increased

var current_state: String = "menu"
var score: int = 0
var distance: float = 0.0
var is_paused: bool = false
var game_speed: float = SCConstants.BASE_SPEED
var spawn_rate: float = SCConstants.PEDESTRIAN_SPAWN_RATE_MAX
var score_multiplier: float = 1.0
var current_phase: int = 1  # Track current game phase (1: Empty Road, 2: Pedestrians, 3: Signal)

var _difficulty_distance_tracker: float = 0.0

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

	_difficulty_distance_tracker = value
	if int(_difficulty_distance_tracker) % int(SCConstants.DIFFICULTY_INCREASE_DISTANCE) == 0 and int(_difficulty_distance_tracker) > 0:
		increase_difficulty()

func increase_difficulty() -> void:
	game_speed = min(game_speed * SCConstants.SPEED_INCREMENT, SCConstants.MAX_SPEED)
	spawn_rate = max(spawn_rate - SCConstants.PEDESTRIAN_SPAWN_RATE_DECREMENT, SCConstants.PEDESTRIAN_SPAWN_RATE_MIN)
	score_multiplier = score_multiplier * SCConstants.SCORE_MULTIPLIER_INCREMENT
	difficulty_increased.emit()

func reset_game() -> void:
	score = 0
	distance = 0.0
	is_paused = false
	game_speed = SCConstants.BASE_SPEED
	spawn_rate = SCConstants.PEDESTRIAN_SPAWN_RATE_MAX
	score_multiplier = 1.0
	_difficulty_distance_tracker = 0.0

func toggle_pause() -> void:
	is_paused = !is_paused

func end_game(final_score: int, final_distance: float) -> void:
	game_over.emit(final_score, final_distance)
