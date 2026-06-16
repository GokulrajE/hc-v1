class_name CatchGameMain

extends Node2D

## Game Settings
const GAME_DURATION: float = 60.0
const HAND_SPEED: float = 500.0  # pixels per second
const MAX_HAND_SPREAD_LEFT: float = 860.0  # max distance from center to left edge
const MAX_HAND_SPREAD_RIGHT: float = 860.0  # max distance from center to right edge
const SPAWN_RATE: float = 1.0  # One object at a time
const FALL_SPEED: float = 300.0  # pixels per second

## Asset paths
const ASSET_FILE: String = "res://assets/catchgame/catch_game.png"
const WANTED_OBJECTS: Array = ["apple", "diamond"]  # Objects to catch
const UNWANTED_OBJECTS: Array = ["donut"]  # Objects to avoid

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


func _ready() -> void:
	_center_x = get_viewport_rect().size.x / 2.0
	_reset_hand_positions()
	_setup_ui()
	print("🎮 Catch Game Ready")
	print("   ▶️ Press SPACEBAR to start")
	print("   ➡️ RIGHT ARROW - Move hands apart")
	print("   ⬅️ LEFT ARROW - Bring hands together")


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


## Update hand positions based on input
func _update_hand_positions(delta: float) -> void:
	var spread_change = 0.0

	# Right arrow - move apart
	if Input.is_action_pressed("ui_right"):
		spread_change = HAND_SPEED * delta

	# Left arrow - move together
	if Input.is_action_pressed("ui_left"):
		spread_change = -HAND_SPEED * delta

	# Update spread (clamp to 0 to MAX)
	_hand_spread_left = clamp(_hand_spread_left + spread_change, 0.0, MAX_HAND_SPREAD_LEFT)
	_hand_spread_right = clamp(_hand_spread_right + spread_change, 0.0, MAX_HAND_SPREAD_RIGHT)

	# Calculate hand positions (no division - full spread)
	_left_hand_pos.x = _center_x - _hand_spread_left
	_right_hand_pos.x = _center_x + _hand_spread_right

	# Clamp to screen bounds
	_left_hand_pos.x = clamp(_left_hand_pos.x, 100, 1820)
	_right_hand_pos.x = clamp(_right_hand_pos.x, 100, 1820)


## Spawn a falling object (wanted or unwanted)
func _spawn_object() -> void:
	# Randomly choose wanted (70%) or unwanted (30%)
	var is_wanted = randf() < 0.7

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
		_:
			print("⚠️ Unknown object type: %s" % obj["object_type"])
			return

	# Duplicate the template sprite
	var sprite = template_sprite.duplicate()
	sprite.position = obj["position"]

	# Tint color based on wanted/unwanted
	if obj["is_wanted"]:
		sprite.self_modulate = Color.WHITE  # Normal color for wanted
	else:
		sprite.self_modulate = Color(1, 0.5, 0.5, 1)  # Reddish tint for unwanted

	add_child(sprite)
	obj["node"] = sprite


## Create a simple circle texture for objects
func create_circle_texture(radius: int, color: Color) -> Texture2D:
	var image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)

	for x in range(radius * 2):
		for y in range(radius * 2):
			var dx = x - radius
			var dy = y - radius
			if dx * dx + dy * dy <= radius * radius:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)

	return ImageTexture.create_from_image(image)


## Update all falling objects
func _update_falling_objects(delta: float) -> void:
	var objects_to_remove = []

	for i in range(_active_objects.size()):
		var obj = _active_objects[i]

		if obj["caught"]:
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
	var obj_rect = Rect2(obj["position"] - Vector2(20, 20), Vector2(40, 40))

	# Check left hand collision shape
	if left_hand_collision and left_hand_collision.shape:
		var left_shape_rect = left_hand_collision.shape.get_rect().grow(5)
		left_shape_rect.position += left_hand.global_position
		if obj_rect.intersects(left_shape_rect):
			return true

	# Check right hand collision shape
	if right_hand_collision and right_hand_collision.shape:
		var right_shape_rect = right_hand_collision.shape.get_rect().grow(5)
		right_shape_rect.position += right_hand.global_position
		if obj_rect.intersects(right_shape_rect):
			return true

	return false


## Handle caught object
func _handle_catch(obj: Dictionary) -> void:
	if obj["is_wanted"]:
		_score += 10
		_caught_objects += 1
		print("✅ Caught wanted object! Score: %d" % _score)
		if ui and ui.has_method("show_success"):
			ui.show_success()
	else:
		_score -= 5
		_missed_objects += 1
		print("❌ Caught unwanted object! Score: %d" % _score)
		if ui and ui.has_method("show_failure"):
			ui.show_failure()


## Handle missed object
func _handle_miss(obj: Dictionary) -> void:
	if obj["is_wanted"]:
		_missed_objects += 1
		print("😞 Missed wanted object!")
	# Unwanted objects are OK to miss


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
	_active_objects.clear()
	_spawn_timer = 0.0  # Spawn first object immediately

	if ui and ui.has_method("show_playing"):
		ui.show_playing()


## End game
func _end_game() -> void:
	print("⏹️ GAME ENDED")
	_is_playing = false

	# Calculate stats
	var success_rate = 0.0
	if _caught_objects + _missed_objects > 0:
		success_rate = (_caught_objects / float(_caught_objects + _missed_objects)) * 100.0

	print("📊 Final Results:")
	print("   Score: %d" % _score)
	print("   Caught: %d" % _caught_objects)
	print("   Missed: %d" % _missed_objects)
	print("   Success Rate: %.1f%%" % success_rate)

	# Show game over panel
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(_score, _caught_objects, _missed_objects, success_rate)
		print("Game Over Screen Displayed ✓")

	# Clear objects
	for obj in _active_objects:
		if obj["node"]:
			obj["node"].queue_free()
	_active_objects.clear()
