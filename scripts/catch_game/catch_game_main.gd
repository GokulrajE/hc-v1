class_name CatchGameMain

extends Node2D

## Game Settings
const GAME_DURATION: float = 60.0
const HAND_SPEED: float = 500.0  # pixels per second
const MAX_HAND_SPREAD_LEFT: float = 960  # max distance from center to left edge
const MAX_HAND_SPREAD_RIGHT: float = 1820.0  # max distance from center to right edge
const SPAWN_RATE: float = 1.0  # One object at a time
const FALL_SPEED: float = 300.0  # pixels per second
const SPAWN_DELAY: float = 0.05
const RESULT_DELAY: float = 0.6

## Asset paths
const ASSET_FILE: String = "res://assets/catchgame/catch_game.png"
const WANTED_OBJECTS: Array = ["apple", "diamond","donut","goldcoin"]  # Objects to catch
const UNWANTED_OBJECTS: Array = ["bomb", "scissor","knife"]  # Objects to avoid

## Hand references
@onready var left_hand = $Hands/LeftHand
@onready var right_hand = $Hands/RightHand
@onready var spawner = $ObjectSpawner
@onready var ui = $CatchGameUI
@onready var timer_label = $CatchGameUI/Control/TimerLabel

## Sprite references for falling objects
@onready var sprite_apple = $apple
@onready var sprite_diamond = $diamond
@onready var sprite_donut = $donut
@onready var sprite_knife= $knife
@onready var sprite_bomb = $bomb
@onready var sprite_scissor = $scissor
@onready var sprite_goldcoin = $goldcoin
## Collision shape references for catch detection
@onready var left_hand_collision = $Hands/LeftHand/CollisionShape2D
@onready var right_hand_collision = $Hands/RightHand/CollisionShape2D

## Game state
enum GameState { WAITING, START, SPAWN, MOVE, SUCCESS, FAILURE, STOP, DONE }
var _game_state: GameState = GameState.WAITING
var _is_game_started: bool = false
var _run_once: bool = false
var _event_delay_timer: float = 0.0
var _time_left: float = GAME_DURATION
var _score: int = 0
var _caught_objects: int = 0
var _missed_objects: int = 0
var _hand_spread_left: float = 0.0  # Current spread from center
var _hand_spread_right: float = 0.0
## Hand positions
var _left_hand_pos: Vector2
var _right_hand_pos: Vector2
var _center_x: float = 960  # Center of screen

## Falling objects — single object tracking
var _current_obj: Dictionary = {}
var _avoided_objects: int = 0
var _caught_unwanted: int = 0
var _last_object_type: String = ""
var _consecutive_unwanted: int = 0
var _consecutive_wanted: int = 0
var _shake_offset: float = 0.0

## Device control
const MAX_DEVICE_SPREAD: float = 290.0
var _use_device: bool = false
var _arom_min: float = 2.0
var _arom_max: float = 6.0
var _moving_avg: float = 0.0
var _moving_avg_counter: int = 0
const MOVING_AVG_LEN: int = 10


func _ready() -> void:
	_center_x = get_viewport_rect().size.x / 2.0
	_reset_hand_positions()
	_setup_ui()
	_connect_device()
	if ui:
		ui.exit_pressed.connect(exit_game)
		ui.restart_pressed.connect(restart_game)
	print("🎮 Catch Game Ready")
	print("   ▶️ Press SPACEBAR to start")


func _connect_device() -> void:
	var mech_name := Appdata.selected_mechanism.name if Appdata.selected_mechanism != null else ""
	if mech_name == "PINCH BUTTON":
		# No AROM for pinch button; buttons are polled directly each frame
		_use_device = HCcomm != null and HCcomm.device_is_connected
		print("🎮 Catch Game: PINCH BUTTON mode — device: %s" % ("active" if _use_device else "fallback"))
		return
	if Appdata.selected_mechanism != null:
		var arom = Appdata.selected_mechanism.get_current_arom()
		if arom[1] > arom[0]:
			_arom_min = arom[0]
			_arom_max = arom[1]
	if _arom_max <= _arom_min:
		_arom_min = 2.0
		_arom_max = 6.0
	if HCcomm and HCcomm.device_is_connected:
		if not HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.new_device_data.connect(_on_device_data_received)
		_use_device = true
		print("🎮 Catch Game: device control active — AROM %.2f–%.2f" % [_arom_min, _arom_max])
	else:
		print("🎮 Catch Game: no device — keyboard fallback (← →)")


func _on_device_data_received() -> void:
	if _game_state != GameState.MOVE:
		return
	var mech_name := Appdata.selected_mechanism.name if Appdata.selected_mechanism != null else ""
	if mech_name == "PINCH BUTTON":
		# No button = hands fully open; button pressed = hands closed to catch
		var any_btn := HCcomm.button_1== 0 or HCcomm.button_2== 0 or HCcomm.button_3== 0 \
					or HCcomm.button_4== 0 or HCcomm.button_5== 0
		var spread := 0.0 if any_btn else MAX_DEVICE_SPREAD
		_hand_spread_left  = spread
		_hand_spread_right = spread
	else:
		var raw := HCcomm.get_btw_distance()
		_moving_avg_counter += 1
		if _moving_avg_counter > MOVING_AVG_LEN:
			_moving_avg = _moving_avg + (raw - _moving_avg) / (MOVING_AVG_LEN + 1)
		else:
			_moving_avg += raw
			if _moving_avg_counter == MOVING_AVG_LEN:
				_moving_avg = _moving_avg / _moving_avg_counter
		var arom_range: float = max(_arom_max - _arom_min, 0.01)
		var normalized: float = clamp((_moving_avg - _arom_min) / arom_range, 0.0, 1.0)
		var spread: float = normalized * MAX_DEVICE_SPREAD
		_hand_spread_left  = spread
		_hand_spread_right = spread


func _exit_tree() -> void:
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))


func _process(_delta: float) -> void:
	if _game_state == GameState.WAITING:
		if Input.is_action_just_pressed("ui_select"):
			_is_game_started = true


func _physics_process(delta: float) -> void:
	match _game_state:
		GameState.MOVE, GameState.SUCCESS, GameState.FAILURE:
			_update_hand_positions(delta)
			left_hand.position.x = _left_hand_pos.x - _shake_offset
			right_hand.position.x = _right_hand_pos.x + _shake_offset
	_run_game_state_machine(delta)


func _run_game_state_machine(delta: float) -> void:
	var is_time_up := false
	if _game_state not in [GameState.WAITING, GameState.STOP, GameState.DONE]:
		_time_left = maxf(_time_left - delta, 0.0)
		if ui: ui.update_timer(_time_left)
		is_time_up = _time_left <= 0.0

	match _game_state:
		GameState.WAITING:
			if _is_game_started:
				_game_state = GameState.START

		GameState.START:
			_initialize_game()
			_game_state = GameState.SPAWN

		GameState.SPAWN:
			if not _run_once:
				_spawn_single_object()
				_event_delay_timer = SPAWN_DELAY
				_run_once = true
			else:
				_event_delay_timer -= delta
				if _event_delay_timer <= 0.0:
					_game_state = GameState.MOVE

		GameState.MOVE:
			var node = _current_obj.get("node")
			if node and is_instance_valid(node):
				_current_obj["position"].y += FALL_SPEED * delta
				node.position = _current_obj["position"]
				var hand = _get_catching_hand(_current_obj)
				if hand != null:
					_current_obj["caught"] = true
					_handle_catch(_current_obj, hand)
				elif _current_obj["position"].y > 1080:
					_handle_miss(_current_obj)
			else:
				# Object gone unexpectedly — treat as miss
				_game_state = GameState.FAILURE
				_event_delay_timer = RESULT_DELAY

		GameState.SUCCESS, GameState.FAILURE:
			_event_delay_timer -= delta
			if _event_delay_timer <= 0.0:
				_run_once = false
				_free_current_obj()
				_game_state = GameState.STOP if is_time_up else GameState.SPAWN

		GameState.STOP:
			_end_game()
			_game_state = GameState.DONE

		GameState.DONE:
			pass


## Reset hand positions to center
func _reset_hand_positions() -> void:
	_hand_spread_left = 0.0
	_hand_spread_right = 0.0
	_left_hand_pos = Vector2(_center_x - 100, 900)
	_right_hand_pos = Vector2(_center_x + 100, 900)
	left_hand.position = _left_hand_pos
	right_hand.position = _right_hand_pos


## Update hand positions based on input or device
func _update_hand_positions(delta: float) -> void:
	var mech_name := Appdata.selected_mechanism.name if Appdata.selected_mechanism != null else ""
	if mech_name == "PINCH BUTTON" and HCcomm != null and HCcomm.device_is_connected:
		# Read buttons directly every frame: no button = open, button pressed = closed (catch)
		var any_btn := HCcomm.button_1== 0 or HCcomm.button_2== 0 or HCcomm.button_3== 0 \
					or HCcomm.button_4== 0 or HCcomm.button_5== 0
		var spread := 0.0 if any_btn else MAX_DEVICE_SPREAD
		_hand_spread_left  = spread
		_hand_spread_right = spread
	elif not _use_device:
		var spread_change := 0.0
		if Input.is_action_pressed("ui_right"):
			spread_change = HAND_SPEED * delta
		if Input.is_action_pressed("ui_left"):
			spread_change = -HAND_SPEED * delta
		_hand_spread_left = clamp(_hand_spread_left + spread_change, 0.0, _center_x)
		_hand_spread_right = clamp(_hand_spread_right + spread_change, 0.0, _center_x + 100.0)

	_left_hand_pos.x = clamp(_center_x - _hand_spread_left, _center_x - 300, _center_x)
	_right_hand_pos.x = clamp(_center_x + _hand_spread_right, _center_x, _center_x + 300)


## Free the current falling object node
func _free_current_obj() -> void:
	var node = _current_obj.get("node")
	if node and is_instance_valid(node):
		node.queue_free()
	_current_obj.clear()


## Spawn a single falling object (wanted or unwanted)
func _spawn_single_object() -> void:
	_free_current_obj()
	var is_wanted = randf() < 0.5

	# Enforce max 2 consecutive from the same group
	if not is_wanted and _consecutive_unwanted >= 2:
		is_wanted = true
	elif is_wanted and _consecutive_wanted >= 2:
		is_wanted = false

	# Pick a type that differs from the last one
	var object_type = ""
	var attempts := 0
	while attempts < 10:
		var pool = WANTED_OBJECTS if is_wanted else UNWANTED_OBJECTS
		object_type = pool[randi() % pool.size()]
		if object_type != _last_object_type:
			break
		attempts += 1
	_last_object_type = object_type

	if is_wanted:
		_consecutive_wanted += 1
		_consecutive_unwanted = 0
	else:
		_consecutive_unwanted += 1
		_consecutive_wanted = 0

	# Always spawn at center X
	var spawn_x = _center_x
	_current_obj = {
		"position": Vector2(spawn_x, -50),
		"velocity": Vector2(0, FALL_SPEED),
		"is_wanted": is_wanted,
		"object_type": object_type,
		"caught": false,
		"node": null
	}
	_create_object_visual(_current_obj)
	print("🎯 Spawned %s object: %s" % ["wanted" if is_wanted else "unwanted", object_type])


## Create visual representation of falling object
func _create_object_visual(obj: Dictionary) -> void:
	# Get the appropriate sprite template from the scene
	var template_sprite: Sprite2D = null
	match obj["object_type"]:
		"apple":
			template_sprite = sprite_apple
		"diamond":
			template_sprite = sprite_diamond
		"donut":
			template_sprite = sprite_donut
		"bomb":
			template_sprite = sprite_bomb
		"scissor":
			template_sprite = sprite_scissor
		"knife":
			template_sprite = sprite_knife
		"goldcoin":
			template_sprite = sprite_goldcoin
		_:
			print("⚠️ Unknown object type: %s" % obj["object_type"])
			return

	# Duplicate the template sprite
	var sprite = template_sprite.duplicate()
	sprite.position = obj["position"]

	# Tint color based on wanted/unwanted
	# if obj["is_wanted"]:
	# 	sprite.self_modulate = Color.WHITE  # Normal color for wanted
	# else:
	# 	sprite.self_modulate = Color(1, 0.5, 0.5, 1)  # Reddish tint for unwanted

	add_child(sprite)
	obj["node"] = sprite


## Returns the hand node that caught the object, or null if no collision
func _get_catching_hand(obj: Dictionary):
	var half := Vector2(25, 25)
	var obj_rect = Rect2(obj["position"] - half, half * 2)

	if left_hand_collision and left_hand_collision.shape:
		var shape_rect = left_hand_collision.shape.get_rect()
		shape_rect.position += left_hand_collision.global_position
		if obj_rect.intersects(shape_rect):
			return left_hand

	if right_hand_collision and right_hand_collision.shape:
		var shape_rect = right_hand_collision.shape.get_rect()
		shape_rect.position += right_hand_collision.global_position
		if obj_rect.intersects(shape_rect):
			return right_hand

	return null


## Spawn a floating score label: pop in → hold → drift up + fade
func _spawn_score_text(pos: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.add_theme_font_size_override("font_size", 120)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(520, 0)
	lbl.position = pos - Vector2(260, 64)
	lbl.z_index = 30
	add_child(lbl)

	var tw := create_tween()
	# Pop in: shrink font from 120 → 92 quickly
	tw.tween_method(
		func(s: float): lbl.add_theme_font_size_override("font_size", int(s)),
		120.0, 92.0, 0.15
	)
	# Hold fully visible
	tw.tween_interval(0.55)
	# Drift up 240 px while fading out
	tw.tween_property(lbl, "position:y", pos.y - 240.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


## Handle caught object
func _handle_catch(obj: Dictionary, hand: Node2D) -> void:
	var screen_center := Vector2(_center_x, 480)
	var flash_color: Color
	if obj["is_wanted"]:
		_score += 1
		_caught_objects += 1
		flash_color = Color(0.2, 0.95, 0.4)
		ScAudioManager.play_cg_success()
		_spawn_score_text(screen_center, "+1", flash_color)
		if ui and ui.has_method("show_success"):
			ui.show_success()
		if ui: ui.update_score(_score)
	else:
		_caught_unwanted += 1
		flash_color = Color(1.0, 0.3, 0.3)
		ScAudioManager.play_cg_wrong()
		_spawn_score_text(screen_center, "WRONG!", flash_color)
		if ui and ui.has_method("show_failure"):
			ui.show_failure()
	_animate_catch(obj, hand, flash_color)
	_game_state = GameState.SUCCESS if obj["is_wanted"] else GameState.FAILURE
	_event_delay_timer = 0.0


## Handle missed object
func _handle_miss(obj: Dictionary) -> void:
	var screen_center := Vector2(_center_x, 480)
	if obj["is_wanted"]:
		_missed_objects += 1
		ScAudioManager.play_cg_miss()
		_spawn_score_text(screen_center, "MISS!", Color(1.0, 0.55, 0.1))
		_animate_miss()
		if ui and ui.has_method("show_failure"):
			ui.show_failure()
		_game_state = GameState.FAILURE
	else:
		_avoided_objects += 1
		_score += 1
		ScAudioManager.play_cg_success()
		_spawn_score_text(screen_center, "DODGE! +1", Color(0.2, 0.95, 0.4))
		if ui and ui.has_method("show_success"):
			ui.show_success()
		if ui: ui.update_score(_score)
		_game_state = GameState.SUCCESS
	_event_delay_timer = 0.0


## Effects 1+2+3+4: hand punch, color flash, object squash, burst dots
func _animate_catch(obj: Dictionary, _hand: Node2D, color: Color) -> void:
	# 3. Object squash-pop before disappearing
	var sprite = obj["node"]
	if sprite:
		var tw_obj := create_tween()
		tw_obj.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.06)
		tw_obj.tween_property(sprite, "scale", Vector2(0.0, 0.0), 0.10)
		tw_obj.tween_callback(sprite.queue_free)
		obj["node"] = null  # removal loop skips queue_free since tween owns it

	# 1. Hand punch scale — both hands
	for h in [left_hand, right_hand]:
		var tw_scale := create_tween()
		tw_scale.tween_property(h, "scale", Vector2(1.3, 1.3), 0.10)
		tw_scale.tween_property(h, "scale", Vector2(1.0, 1.0), 0.15)

	# 2. Hand color flash — both hands
	left_hand.self_modulate = color
	right_hand.self_modulate = color
	var tw_color := create_tween()
	tw_color.tween_property(left_hand, "self_modulate", Color.WHITE, 0.25)
	tw_color.parallel().tween_property(right_hand, "self_modulate", Color.WHITE, 0.25)

	# 4. Burst dots at catch position
	_spawn_burst(obj["position"], color)


## Effect 4: colored dots burst outward from catch point
func _spawn_burst(pos: Vector2, color: Color) -> void:
	const DOT_COUNT := 8
	const BURST_DIST := 160.0
	const DOT_SIZE := 14.0

	for i in DOT_COUNT:
		var angle := (TAU / DOT_COUNT) * i
		var target := pos + Vector2(cos(angle), sin(angle)) * BURST_DIST

		var dot := ColorRect.new()
		dot.size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = color
		dot.position = pos - Vector2(DOT_SIZE * 0.5, DOT_SIZE * 0.5)
		dot.z_index = 25
		add_child(dot)

		var tw := create_tween()
		tw.tween_property(dot, "position", target - Vector2(DOT_SIZE * 0.5, DOT_SIZE * 0.5), 0.40)
		tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.40)
		tw.tween_callback(dot.queue_free)


## Effect 5: both hands shake horizontally when a wanted object is missed
func _animate_miss() -> void:
	var tw := create_tween()
	for _i in 3:
		tw.tween_property(self, "_shake_offset", 14.0, 0.04)
		tw.tween_property(self, "_shake_offset", -14.0, 0.04)
	tw.tween_property(self, "_shake_offset", 0.0, 0.03)


## Setup UI
func _setup_ui() -> void:
	if ui and ui.has_method("setup"):
		ui.setup(GAME_DURATION)


## Initialize game
func _initialize_game() -> void:
	print("▶️ GAME STARTED - 60 seconds")
	_score = 0
	_time_left = GAME_DURATION
	_caught_objects = 0
	_missed_objects = 0
	_avoided_objects = 0
	_caught_unwanted = 0
	_free_current_obj()
	_run_once = false
	_event_delay_timer = 0.0
	_last_object_type = ""
	_consecutive_unwanted = 0
	_consecutive_wanted = 0
	_shake_offset = 0.0
	_reset_hand_positions()
	if Appdata.selected_mechanism != null:
		AppDataTrial.start_new_trial()
	ScAudioManager.play_background_music("res://assets/audio/cg_bg.mp3")
	if ui and ui.has_method("show_playing"):
		ui.show_playing()
	if ui:
		ui.update_score(0)
		ui.update_timer(GAME_DURATION)


## End game
func _end_game() -> void:
	print("⏹️ GAME ENDED")
	_free_current_obj()
	var total = _caught_objects + _missed_objects + _caught_unwanted + _avoided_objects
	var correct = _caught_objects + _avoided_objects
	var wrong = _missed_objects + _caught_unwanted
	var success_rate = (correct / float(max(total, 1))) * 100.0
	if Appdata.selected_mechanism != null:
		AppDataTrial.stop_trial(total, correct, wrong)
	ScAudioManager.stop_music()
	ScAudioManager.play_gameover()
	print("📊 Final Results:")
	print("   Score: %d" % _score)
	print("   Caught wanted: %d | Missed wanted: %d" % [_caught_objects, _missed_objects])
	print("   Dodged unwanted: %d | Caught unwanted: %d" % [_avoided_objects, _caught_unwanted])
	print("   Success Rate: %.1f%%" % success_rate)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(_score, _caught_objects, _missed_objects,
						  _avoided_objects, _caught_unwanted, success_rate)


func restart_game() -> void:
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func exit_game() -> void:
	if _game_state not in [GameState.WAITING, GameState.DONE]:
		_game_state = GameState.STOP
