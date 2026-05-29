class_name SCGame

extends Node2D

@onready var car = $Car
@onready var spawner = $Spawner
@onready var ui = $UI
@onready var pause_menu = $PauseMenu

var _game_state: SCGameState
var _scroll_manager: Node
var _traffic_signal
var _distance_traveled: float = 0.0
var _is_game_over: bool = false
var _current_phase: int = 1
var _phase_timer: float = 3.0
var _phase_durations: Dictionary = {1: 3.0, 2: 5.0, 3: 5.0}

# Space bar braking system
var _base_speed: float = SCConstants.BASE_SPEED
var _target_speed: float = SCConstants.BASE_SPEED
var _is_braking: bool = false
const BRAKE_DECELERATION: float = 500.0  # Speed reduction per second
const BRAKE_ACCELERATION: float = 300.0  # Speed increase per second when releasing

func _ready() -> void:
	_game_state = SCGameState.new()
	_game_state.enter_state(SCGameState.State.PLAYING)

	# Create scroll manager
	_scroll_manager = load("res://scripts/safecrossing/game/sc_scroll_manager.gd").new()
	add_child(_scroll_manager)
	move_child(_scroll_manager, 0)

	_traffic_signal = load("res://scripts/safecrossing/entities/sc_traffic_signal.gd").new()
	add_child(_traffic_signal)

	car.collision_detected.connect(_on_car_collision)
	_traffic_signal.signal_changed.connect(_on_signal_changed)
	SCGameManager.game_state_changed.connect(_on_game_state_changed)

	ui.visible = true
	pause_menu.visible = false

	# Position car at bottom center lane - visible in all scenes
	var center_lane_x = SCConstants.ROAD_OFFSET_X + 1 * SCConstants.CAR_LANE_WIDTH  # Lane 1 (center)
	car.position = Vector2(center_lane_x, 1000)  # Bottom center of viewport
	car.visible = true

	_distance_traveled = 0.0
	_current_phase = 1
	_phase_timer = _phase_durations[1]
	SCGameManager.reset_game()

func _physics_process(delta: float) -> void:
	if _is_game_over or SCGameManager.is_paused:
		return

	_distance_traveled += SCGameManager.game_speed * delta
	SCGameManager.set_distance(_distance_traveled)

	# Update scroll
	_scroll_manager.update_scroll(delta, SCGameManager.game_speed)

	# Update phase based on scroll position
	var new_phase = _scroll_manager.get_current_phase()
	if new_phase != _current_phase:
		_on_phase_changed(new_phase)

	# Update phase timer
	_phase_timer -= delta
	if _phase_timer <= 0:
		_phase_timer = _phase_durations[_current_phase]

	spawner.spawn_rate = SCGameManager.spawn_rate
	car.max_speed = SCGameManager.game_speed

	_update_phase_display()

func _process(delta: float) -> void:
	# Handle space bar braking
	if Input.is_action_pressed("ui_select") and not _is_game_over:  # space bar = ui_select
		if not _is_braking:
			_is_braking = true
			_target_speed = 0.0
	elif _is_braking:
		_is_braking = false
		_target_speed = _base_speed

	# Smoothly transition to target speed
	if SCGameManager.game_speed != _target_speed:
		var speed_diff = _target_speed - SCGameManager.game_speed
		var decel_rate = BRAKE_DECELERATION if _is_braking else BRAKE_ACCELERATION

		if abs(speed_diff) < decel_rate * delta:
			SCGameManager.game_speed = _target_speed
		else:
			SCGameManager.game_speed += sign(speed_diff) * decel_rate * delta

	if Input.is_action_just_pressed("ui_pause") and not _is_game_over:
		_toggle_pause()

func _toggle_pause() -> void:
	if _game_state.is_state(SCGameState.State.PLAYING):
		_game_state.enter_state(SCGameState.State.PAUSED)
		SCGameManager.toggle_pause()
		get_tree().paused = true
		pause_menu.visible = true
	elif _game_state.is_state(SCGameState.State.PAUSED):
		_game_state.enter_state(SCGameState.State.PLAYING)
		SCGameManager.toggle_pause()
		get_tree().paused = false
		pause_menu.visible = false

func _on_car_collision(_pedestrian: Node2D) -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_game_state.enter_state(SCGameState.State.GAME_OVER)
	SCGameManager.end_game(SCGameManager.score, _distance_traveled)

	ui.show_game_over()
	spawner.stop_spawning()

	car.set_process(false)
	car.set_physics_process(false)
	spawner.set_process(false)


func _on_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase
	SCGameManager.current_phase = new_phase  # Update global phase tracker
	_phase_timer = _phase_durations[new_phase]

	match new_phase:
		1:  # EMPTY_ROAD
			print("Phase 1: Empty Road")
		2:  # PEDESTRIANS
			print("Phase 2: Pedestrians Crossing")
			# _reset_pedestrians()
		3:  # SIGNAL
			print("Phase 3: Traffic Signal")

func _on_signal_changed(is_green: bool) -> void:
	ui.update_signal_display(is_green)

func _update_phase_display() -> void:
	var phase_names = {1: "Empty Road", 2: "Pedestrians", 3: "Signal"}
	var phase_name = phase_names.get(_current_phase, "Unknown")
	ui.update_phase_display(phase_name, _phase_timer)

func _on_game_state_changed(new_state: String) -> void:
	match new_state:
		"menu":
			pass
		"playing":
			pause_menu.visible = false
		"paused":
			pause_menu.visible = true
		"game_over":
			pass

func _reset_pedestrians() -> void:
	# Find the PedestriansWalk environment (phase 2 = environment index 1)
	if _scroll_manager and _scroll_manager.environments.size() > 1:
		var pedestrians_scene = _scroll_manager.environments[1]
		var character = pedestrians_scene.get_node_or_null("character")
		if character and character.has_method("reset_position"):
			character.reset_position()

func resume_game() -> void:
	if _game_state.is_state(SCGameState.State.PAUSED):
		_toggle_pause()

func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/main.tscn")
