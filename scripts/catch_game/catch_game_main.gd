class_name CatchGameMain

extends Node2D

## Game Settings
const GAME_DURATION: float = 60.0
const HAND_SPEED: float = 500.0  # pixels per second
const MAX_HAND_SPREAD_LEFT: float = 960  # max distance from center to left edge
const MAX_HAND_SPREAD_RIGHT: float = 1820.0  # max distance from center to right edge
const SPAWN_RATE: float = 1.0  # One object at a time
const FALL_SPEED: float = 300.0  # pixels per second

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
var _is_playing: bool = false
var _time_left: float = GAME_DURATION
var _score: int = 0
var _caught_objects: int = 0
var _missed_objects: int = 0
var _hand_spread_left: float = 0.0  # Current spread from center
var _hand_spread_right:float =0.0
## Hand positions
var _left_hand_pos: Vector2
var _right_hand_pos: Vector2
var _center_x: float = 960  # Center of screen

## Falling objects
var _active_objects: Array = []
var _spawn_timer: float = 0.0
var _avoided_objects: int = 0
var _caught_unwanted: int = 0

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
		ui.exit_pressed.connect(_on_ui_exit_pressed)
		ui.restart_pressed.connect(_start_game)
	print("🎮 Catch Game Ready")
	print("   ▶️ Press SPACEBAR to start")


func _connect_device() -> void:
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
	if not _is_playing:
		return
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
	_hand_spread_left = spread
	_hand_spread_right = spread


func _exit_tree() -> void:
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))


func _physics_process(delta: float) -> void:
	if not _is_playing:
		# Wait for start input
		if Input.is_action_just_pressed("ui_select"):
			_start_game()
		return

	# Update timer
	_time_left -= delta
	if _time_left <= 0:
		_end_game()
		return

	# Handle hand movement
	_update_hand_positions(delta)

	# Update hand visuals
	left_hand.position.x = _left_hand_pos.x
	right_hand.position.x = _right_hand_pos.x

	# Spawn objects (only if no active objects exist)
	if _active_objects.size() == 0:
		_spawn_object()
		_spawn_timer = 0.5  # Small delay before spawning next

	# Update falling objects
	_update_falling_objects(delta)

	# Update UI
	_update_ui(delta)


func _process(_delta: float) -> void:
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
	if not _use_device:
		var spread_change := 0.0
		if Input.is_action_pressed("ui_right"):
			spread_change = HAND_SPEED * delta
		if Input.is_action_pressed("ui_left"):
			spread_change = -HAND_SPEED * delta
		_hand_spread_left = clamp(_hand_spread_left + spread_change, 0.0, _center_x)
		_hand_spread_right = clamp(_hand_spread_right + spread_change, 0.0, _center_x + 100.0)

	_left_hand_pos.x = clamp(_center_x - _hand_spread_left, _center_x - 300, _center_x)
	_right_hand_pos.x = clamp(_center_x + _hand_spread_right, _center_x, _center_x + 300)


## Spawn a falling object (wanted or unwanted)
func _spawn_object() -> void:
	# Randomly choose wanted (50%) or unwanted (50%)
	var is_wanted = randf() < 0.5

	# Pick random object type
	var object_type = ""
	if is_wanted:
		object_type = WANTED_OBJECTS[randi() % WANTED_OBJECTS.size()]
	else:
		object_type = UNWANTED_OBJECTS[randi() % UNWANTED_OBJECTS.size()]

	# Always spawn at center X
	var spawn_x = _center_x

	var obj = {
		"position": Vector2(spawn_x, -50),
		"velocity": Vector2(0, FALL_SPEED),
		"is_wanted": is_wanted,
		"object_type": object_type,
		"caught": false,
		"node": null
	}

	_active_objects.append(obj)

	# Create visual node
	_create_object_visual(obj)
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





## Update all falling objects
func _update_falling_objects(delta: float) -> void:
	var objects_to_remove = []

	for i in range(_active_objects.size()):
		var obj = _active_objects[i]

		if obj["caught"]:
			continue

		if obj["node"] == null:
			objects_to_remove.append(i)
			continue

		# Update position
		obj["position"].y += obj["velocity"].y * delta
		obj["node"].position = obj["position"]

		# Check if caught by hands
		if _check_hand_collision(obj):
			obj["caught"] = true
			_handle_catch(obj)
			objects_to_remove.append(i)
			continue

		# Check if missed (fell past hands)
		if obj["position"].y > 1080:
			_handle_miss(obj)
			objects_to_remove.append(i)

	# Remove caught/missed objects (in reverse order to avoid index shifts)
	objects_to_remove.reverse()
	for i in objects_to_remove:
		if _active_objects[i]["node"]:
			_active_objects[i]["node"].queue_free()
		_active_objects.remove_at(i)


## Check if object collides with either hand using collision shapes
func _check_hand_collision(obj: Dictionary) -> bool:
	# Use half the sprite visual size so the object must reach the hand center
	var half := Vector2(25, 25)
	var obj_rect = Rect2(obj["position"] - half, half * 2)

	# Check left hand — use the collision shape's own global position, not the body root
	if left_hand_collision and left_hand_collision.shape:
		var shape_rect = left_hand_collision.shape.get_rect()
		shape_rect.position += left_hand_collision.global_position
		if obj_rect.intersects(shape_rect):
			return true

	# Check right hand
	if right_hand_collision and right_hand_collision.shape:
		var shape_rect = right_hand_collision.shape.get_rect()
		shape_rect.position += right_hand_collision.global_position
		if obj_rect.intersects(shape_rect):
			return true

	return false


## Spawn a floating score label that drifts upward and fades
func _spawn_score_text(pos: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.position = pos - Vector2(50, 20)
	lbl.z_index = 20
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", pos.y - 110.0, 0.75)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.tween_callback(lbl.queue_free)


## Handle caught object
func _handle_catch(obj: Dictionary) -> void:
	var screen_center := Vector2(_center_x, 480)
	if obj["is_wanted"]:
		_score += 1
		_caught_objects += 1
		_spawn_score_text(screen_center, "+1", Color(0.2, 0.95, 0.4))
		if ui and ui.has_method("show_success"):
			ui.show_success()
	else:
		_caught_unwanted += 1
		_spawn_score_text(screen_center, "WRONG!", Color(1.0, 0.3, 0.3))
		if ui and ui.has_method("show_failure"):
			ui.show_failure()


## Handle missed object
func _handle_miss(obj: Dictionary) -> void:
	var screen_center := Vector2(_center_x, 480)
	if obj["is_wanted"]:
		_missed_objects += 1
		_spawn_score_text(screen_center, "MISS!", Color(1.0, 0.55, 0.1))
		if ui and ui.has_method("show_failure"):
			ui.show_failure()
	else:
		_avoided_objects += 1
		_score += 1
		_spawn_score_text(screen_center, "DODGE! +1", Color(0.2, 0.95, 0.4))
		if ui and ui.has_method("show_success"):
			ui.show_success()


## Update UI display
func _update_ui(_delta: float) -> void:
	if ui:
		ui.update_score(_score)
		ui.update_timer(_time_left)
		# ui.update_hands_spread(_hand_spread / MAX_HAND_SPREAD)


## Setup UI
func _setup_ui() -> void:
	if ui and ui.has_method("setup"):
		ui.setup(GAME_DURATION)


## Start game
func _start_game() -> void:
	print("▶️ GAME STARTED - 60 seconds")
	_is_playing = true
	_time_left = GAME_DURATION
	_score = 0
	_caught_objects = 0
	_missed_objects = 0
	_avoided_objects = 0
	_caught_unwanted = 0
	_active_objects.clear()
	_spawn_timer = 0.0  # Spawn first object immediately

	if ui and ui.has_method("show_playing"):
		ui.show_playing()


func _on_ui_exit_pressed() -> void:
	if _is_playing:
		_end_game()


## End game
func _end_game() -> void:
	print("⏹️ GAME ENDED")
	_is_playing = false

	# Calculate stats — correct = wanted caught + unwanted avoided
	var total = _caught_objects + _missed_objects + _caught_unwanted + _avoided_objects
	var correct = _caught_objects + _avoided_objects
	var success_rate = (correct / float(max(total, 1))) * 100.0

	print("📊 Final Results:")
	print("   Score: %d" % _score)
	print("   Caught wanted: %d | Missed wanted: %d" % [_caught_objects, _missed_objects])
	print("   Dodged unwanted: %d | Caught unwanted: %d" % [_avoided_objects, _caught_unwanted])
	print("   Success Rate: %.1f%%" % success_rate)

	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(_score, _caught_objects, _missed_objects,
						  _avoided_objects, _caught_unwanted, success_rate)
		print("Game Over Screen Displayed ✓")

	# Clear objects
	for obj in _active_objects:
		if obj["node"]:
			obj["node"].queue_free()
	_active_objects.clear()
