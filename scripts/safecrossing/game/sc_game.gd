class_name SCGame

extends Node2D

@onready var car = $car
@onready var spawner = $Spawner
@onready var ui = $UI
@onready var pause_menu = $PauseMenu

enum GameState { WAITING, START, CARMOVING, CARSTOP, SUCCESS, FAILURE, PAUSED, STOP, DONE }
var _game_state: GameState = GameState.WAITING
var _is_game_started: bool = false
var _event_delay_timer: float = 0.0

const RESULT_DELAY: float = 0.8

var _scroll_manager: Node
var _traffic_signal
var _distance_traveled: float = 0.0
var _current_phase: int = 1
var _phase_timer: float = 3.0
var _phase_durations: Dictionary = {1: 3.0, 2: 5.0, 3: 5.0}
var _phase_collided: bool = false
var _failure_sound_played: bool = false
var _player_score: int = 0
var _last_scroll_offset: float = 0.0
# var _crossing_line_y: float = 476.0  # Y position of pedestrian crossing line
# var _traffic_road_y: float = 500.0   # Y position of traffic road area
var _has_scored_this_crossing: bool = false
var _last_pedestrian_line_y: float = -999999.0
var _last_traffic_line_y: float = -999999.0

# Trial duration and timing (60 seconds)
const TRIAL_DURATION: float = 60.0
var _trial_time_left: float = TRIAL_DURATION

# Trial statistics
var _trial_targets: int = 0      # Total crossings attempted
var _trial_successes: int = 0    # Successful crossings
var _trial_failures: int = 0     # Failed crossings (collisions)

# Space bar braking system
var _base_speed: float = SCConstants.BASE_SPEED
var _target_speed: float = SCConstants.BASE_SPEED
var _is_braking: bool = false
const BRAKE_DECELERATION: float = 500.0
const BRAKE_ACCELERATION: float = 300.0

func _ready() -> void:
	SCGameManager.change_state("waiting")

	# Create scroll manager
	_scroll_manager = load("res://scripts/safecrossing/game/sc_scroll_manager.gd").new()
	add_child(_scroll_manager)
	move_child(_scroll_manager, 0)

	# Find pedestrians and traffic cars
	car._find_pedestrians()
	car._find_traffic_cars()

	_traffic_signal = load("res://scripts/safecrossing/entities/sc_traffic_signal.gd").new()
	add_child(_traffic_signal)

	car.collision_detected.connect(_on_car_collision)
	car.traffic_collision_detected.connect(_on_traffic_collision)
	_traffic_signal.signal_changed.connect(_on_signal_changed)
	SCGameManager.game_state_changed.connect(_on_game_state_changed)

	ui.visible = true
	pause_menu.visible = false

	car.position = Vector2(960, 880)  # Move car forward (up the screen)
	car.visible = true

	_distance_traveled = 0.0
	_current_phase = 1
	_phase_timer = _phase_durations[1]
	SCGameManager.reset_game()
	# Initialize trial statistics
	_reset_trial_stats()


func _process(delta: float) -> void:
	if _game_state == GameState.WAITING:
		if Input.is_action_just_pressed("ui_select"):
			_is_game_started = true
		return

	# Detect brake input
	var device_button_pressed := _read_active_input()
	if not device_button_pressed and Input.is_action_pressed("ui_select"):
		device_button_pressed = true

	# State-based brake transitions
	if _game_state == GameState.CARMOVING and device_button_pressed:
		_is_braking = true
		_target_speed = 0.0
		_game_state = GameState.CARSTOP
		print("🛑 Car braking")
	elif _game_state == GameState.CARSTOP and not device_button_pressed:
		_is_braking = false
		_target_speed = _base_speed
		_game_state = GameState.CARMOVING
		print("▶️ Car resuming")

	# Smooth speed transition
	if SCGameManager.game_speed != _target_speed:
		var speed_diff := _target_speed - SCGameManager.game_speed
		var decel_rate := BRAKE_DECELERATION if _is_braking else BRAKE_ACCELERATION
		if abs(speed_diff) < decel_rate * delta:
			SCGameManager.game_speed = _target_speed
		else:
			SCGameManager.game_speed += sign(speed_diff) * decel_rate * delta

	# Pause toggle
	if Input.is_action_just_pressed("ui_cancel") and _game_state in [GameState.CARMOVING, GameState.CARSTOP]:
		_toggle_pause()


func _physics_process(delta: float) -> void:
	if _game_state == GameState.CARMOVING or _game_state == GameState.CARSTOP \
			or _game_state == GameState.SUCCESS or _game_state == GameState.FAILURE:
		_distance_traveled += SCGameManager.game_speed * delta
		SCGameManager.set_distance(_distance_traveled)
		_scroll_manager.update_scroll(delta, SCGameManager.game_speed)
		_check_crossing_lines()

		if int(Engine.get_physics_frames()) % 30 == 0:
			print("⏱️ Trial: %.1f/%.0fs | 🔍 SCROLL: %.0f | PHASE: %d | COLLIDED: %s | SCORE: %d | SUCCESS: %d | FAIL: %d" % [
				TRIAL_DURATION - _trial_time_left, TRIAL_DURATION, _scroll_manager.scroll_offset,
				_current_phase, _phase_collided, _player_score, _trial_successes, _trial_failures
			])

		var new_phase: int = _scroll_manager.get_current_phase()
		if new_phase != _current_phase:
			_on_phase_changed(new_phase)
		_phase_timer -= delta
		if _phase_timer <= 0:
			_phase_timer = _phase_durations[_current_phase]
		spawner.spawn_rate = SCGameManager.spawn_rate
		_update_phase_display()

	_run_game_state_machine(delta)


# ============================================================================
# STATE MACHINE
# ============================================================================

func _run_game_state_machine(delta: float) -> void:
	var is_time_up := false
	if _game_state not in [GameState.WAITING, GameState.PAUSED, GameState.STOP, GameState.DONE]:
		_trial_time_left = maxf(_trial_time_left - delta, 0.0)
		if ui:
			ui.update_timer_display(_trial_time_left)
		is_time_up = _trial_time_left <= 0.0

	match _game_state:
		GameState.WAITING:
			if _is_game_started:
				_game_state = GameState.START

		GameState.START:
			_initialize_game()
			_game_state = GameState.CARMOVING

		GameState.CARMOVING:
			if is_time_up:
				_game_state = GameState.STOP

		GameState.CARSTOP:
			if is_time_up:
				_game_state = GameState.STOP

		GameState.SUCCESS, GameState.FAILURE:
			_event_delay_timer -= delta
			if _event_delay_timer <= 0.0:
				# Reset braking and return to CARMOVING
				_is_braking = false
				_target_speed = _base_speed
				if is_time_up:
					_game_state = GameState.STOP
				else:
					_game_state = GameState.CARMOVING

		GameState.PAUSED:
			pass

		GameState.STOP:
			_end_trial()
			_game_state = GameState.DONE

		GameState.DONE:
			pass


# ============================================================================
# TRIAL MANAGEMENT FUNCTIONS
# ============================================================================

func _initialize_game() -> void:
	SCGameManager.change_state("start")
	_reset_trial_stats()
	_trial_time_left = TRIAL_DURATION
	if ui:
		ui.update_timer_display(TRIAL_DURATION)
	AppDataTrial.start_new_trial()
	ScAudioManager.play_background_music("res://assets/audio/sc_bg.mp3")
	SCGameManager.change_state("playing")
	print("🎮 PLAYING - 60 second trial started")


func _end_trial() -> void:
	print("⏹️ TRIAL ENDED - Time's Up!")
	SCGameManager.change_state("game_over")
	AppDataTrial.stop_trial(_trial_targets, _trial_successes, _trial_failures)
	ScAudioManager.stop_music()
	ScAudioManager.play_gameover()
	print("💾 Trial data saved: Targets=%d, Success=%d, Failures=%d" % [
		_trial_targets, _trial_successes, _trial_failures
	])
	_show_game_over_screen()


func _reset_trial_stats() -> void:
	_trial_targets = 0
	_trial_successes = 0
	_trial_failures = 0
	_player_score = 0
	_distance_traveled = 0.0
	_phase_collided = false
	_failure_sound_played = false
	_has_scored_this_crossing = false
	_last_pedestrian_line_y = -999999.0
	_last_traffic_line_y = -999999.0


func _on_crossing_complete(is_success: bool) -> void:
	_trial_targets += 1

	if is_success:
		_trial_successes += 1
		print("✅ Crossing SUCCESS - Total: %d/%d" % [_trial_successes, _trial_targets])

	else:
		_trial_failures += 1
		print("❌ Crossing FAILED - Total: %d/%d" % [_trial_failures, _trial_targets])


# ============================================================================
# GAME STATE HANDLING
# ============================================================================

func _toggle_pause() -> void:
	if _game_state == GameState.CARMOVING or _game_state == GameState.CARSTOP:
		_game_state = GameState.PAUSED
		SCGameManager.toggle_pause()
		SCGameManager.change_state("paused")
		get_tree().paused = true
		pause_menu.visible = true
		print("⏸️ PAUSED")
	elif _game_state == GameState.PAUSED:
		_game_state = GameState.CARMOVING
		_is_braking = false
		_target_speed = _base_speed
		SCGameManager.toggle_pause()
		SCGameManager.change_state("playing")
		get_tree().paused = false
		pause_menu.visible = false
		print("▶️ RESUMED")


func _on_car_collision(_pedestrian: Node2D) -> void:
	if not _failure_sound_played and (_game_state == GameState.CARMOVING or _game_state == GameState.CARSTOP):
		_phase_collided = true
		_failure_sound_played = true
		print("💥 Collision with pedestrian!")
		ScAudioManager.play_sc_failure()
		if ui and ui.has_method("show_failure_popup"):
			ui.show_failure_popup()


func _on_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase
	SCGameManager.current_phase = new_phase
	_phase_timer = _phase_durations[new_phase]
	_phase_collided = false
	_failure_sound_played = false
	_has_scored_this_crossing = false
	_last_scroll_offset = _scroll_manager.scroll_offset
	_last_pedestrian_line_y = -999999.0
	_last_traffic_line_y = -999999.0

	match new_phase:
		1:
			print("📍 Phase 1: Empty Road")
			_unregister_traffic_cars()
		2:
			print("📍 Phase 2: Pedestrians Crossing")
			_unregister_traffic_cars()
		3:
			print("📍 Phase 3: Traffic Signal")
			_register_traffic_cars()


func _on_signal_changed(is_green: bool) -> void:
	ui.update_signal_display(is_green)


func _update_phase_display() -> void:
	var phase_names = {1: "Empty Road", 2: "Pedestrians", 3: "Signal"}
	var phase_name = phase_names.get(_current_phase, "Unknown")
	var time_str = "%.1f/%.0fs" % [TRIAL_DURATION - _trial_time_left, TRIAL_DURATION]
	ui.update_phase_display("%s [%s]" % [phase_name, time_str], _phase_timer)


func _on_game_state_changed(new_state: String) -> void:
	match new_state:
		"waiting":
			print("🔔 Waiting for player to start game...")
		"start":
			print("🏁 Game starting...")
		"playing":
			print("🎮 Game playing...")
		"paused":
			print("⏸️ Game paused...")
		"game_over":
			print("🏁 Game over!")
		"stopped":
			print("🛑 Game stopped, returning to menu...")


func _check_crossing_lines() -> void:
	var car_y = car.global_position.y

	# Phase 2: Pedestrian crossing
	if _current_phase == 2 and not _has_scored_this_crossing:
		var pedestrians_env = _scroll_manager.environments[1]
		if pedestrians_env and pedestrians_env.visible:
			var collision_line = pedestrians_env.get_node_or_null("collisionline")
			if not collision_line:
				collision_line = pedestrians_env.get_node_or_null("Collisionline")

			if collision_line:
				var line_y = collision_line.global_position.y

				if _last_pedestrian_line_y < car_y and line_y >= car_y:
					print("✅ PHASE 2 CROSSING DETECTED!")
					if not _phase_collided:
						_add_score(1, "Pedestrians")
						_on_crossing_complete(true)
						_game_state = GameState.SUCCESS
					else:
						_on_crossing_complete(false)
						print("❌ Hit pedestrian - no points")
						_game_state = GameState.FAILURE
					_has_scored_this_crossing = true
					_event_delay_timer = RESULT_DELAY
					_is_braking = false
					_target_speed = _base_speed
					SCGameManager.game_speed = _base_speed

				_last_pedestrian_line_y = line_y

	# Phase 3: Traffic crossing
	if _current_phase == 3 and not _has_scored_this_crossing:
		var traffic_env = _scroll_manager.environments[2]
		if traffic_env and traffic_env.visible:
			var collision_line = traffic_env.get_node_or_null("collisionline")
			if not collision_line:
				collision_line = traffic_env.get_node_or_null("Collisionline")

			if collision_line:
				var line_y = collision_line.global_position.y

				if _last_traffic_line_y < car_y and line_y >= car_y:
					print("✅ PHASE 3 CROSSING DETECTED!")
					if not _phase_collided:
						_add_score(1, "Traffic")
						_on_crossing_complete(true)
						_game_state = GameState.SUCCESS
					else:
						_on_crossing_complete(false)
						print("❌ Hit traffic car - no points")
						_game_state = GameState.FAILURE
					_has_scored_this_crossing = true
					_event_delay_timer = RESULT_DELAY
					_is_braking = false
					_target_speed = _base_speed
					SCGameManager.game_speed = _base_speed

				_last_traffic_line_y = line_y


func _add_score(points: int, phase_name: String) -> void:
	_player_score += points
	print("⭐ %s crossing completed safely! Score: %d" % [phase_name, _player_score])
	ScAudioManager.play_sc_success()
	ui.update_score_display(_player_score)
	_trigger_score_feedback()


func _on_traffic_collision(_traffic_car: Node2D) -> void:
	if not _failure_sound_played and (_game_state == GameState.CARMOVING or _game_state == GameState.CARSTOP):
		_phase_collided = true
		_failure_sound_played = true
		print("💥 Collision with traffic car!")
		ScAudioManager.play_sc_failure()
		if ui and ui.has_method("show_failure_popup"):
			ui.show_failure_popup()


func _trigger_score_feedback() -> void:
	if ui and ui.has_method("show_score_popup"):
		ui.show_score_popup()


func _register_traffic_cars() -> void:
	var all_traffic_cars = get_tree().get_nodes_in_group("traffic_car")
	for traffic_car in all_traffic_cars:
		car.add_traffic_car(traffic_car)
		print("🚗 Registered traffic car: ", traffic_car.name)


func _unregister_traffic_cars() -> void:
	var all_traffic_cars = get_tree().get_nodes_in_group("traffic_car")
	for traffic_car in all_traffic_cars:
		car.remove_traffic_car(traffic_car)


func _read_active_input() -> bool:
	if not (HCcomm and HCcomm.device_is_connected):
		return false
	var mech = Appdata.selected_mechanism
	if mech == null:
		return false
	if mech.name == "PINCH":
		var rom := mech.old_rom as PinchROM
		if rom == null:
			return HCcomm.button_7 == 0 or HCcomm.button_6 == 0
		return (rom.pinch1_done and HCcomm.button_7 == 0) or \
			   (rom.pinch2_done and HCcomm.button_6 == 0)
	if mech.name == "BUTTONS":
		return HCcomm.button_1==0 or HCcomm.button_2==0 or HCcomm.button_3==0 \
			   or HCcomm.button_4==0 or HCcomm.button_5==0
	return false


func _show_game_over_screen() -> void:
	print("📊 GAME OVER SCREEN:")
	print("  Score: %d" % _player_score)
	print("  Crossings: %d/%d successful" % [_trial_successes, _trial_targets])
	var success_rate = (_trial_successes / float(_trial_targets) * 100.0) if _trial_targets > 0 else 0.0
	print("  Success Rate: %.1f%%" % success_rate)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(_player_score, _trial_targets, _trial_successes, _trial_failures)


func resume_game() -> void:
	if _game_state == GameState.PAUSED:
		_toggle_pause()


func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func exit_game() -> void:
	
	if _game_state in [GameState.WAITING, GameState.DONE]:
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		_game_state = GameState.STOP
