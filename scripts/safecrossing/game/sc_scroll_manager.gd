class_name SCScrollManager
extends Node2D

# For 1920x1080 screen
const SCENE_HEIGHT: float = 1100.0  # Content height
const SCREEN_HEIGHT: float = 1080.0  # Visible area height
const SPACING: float = 1080.0  # Scene spacing (matches visible area for seamless transitions)
const CYCLE_HEIGHT: float = 3240.0  # 3 scenes * 1080

var scroll_offset: float = 0.0
var environments: Array = []

func _ready() -> void:
	_create_environments()

func _create_environments() -> void:
	var scene_paths = [
		"res://scenes/safecrossing/sc_environment.tscn",      # Phase 1: Empty Road
		"res://scenes/safecrossing/PedestriansWalk.tscn",     # Phase 2: Pedestrians
		"res://scenes/safecrossing/signalScene.tscn",         # Phase 3: Signal
		"res://scenes/safecrossing/sc_environment.tscn"       # Phase 1 repeat (seamless loop)
	]

	for i in range(scene_paths.size()):
		print("Loading environment: ", scene_paths[i])
		var env = load(scene_paths[i]).instantiate()
		# Position scenes ABOVE viewport (negative Y) for top-to-bottom scrolling
		# Each scene is positioned 1080px above the previous one
		env.position.y = -i * SPACING
		add_child(env)
		environments.append(env)
		# Ensure environment is visible
		if env.has_method("set_visible"):
			env.visible = true
		print("Environment ", i, " (", scene_paths[i].get_file(), ") loaded at Y: ", env.position.y, " | Visible: ", env.visible)

func update_scroll(delta: float, speed: float) -> void:
	scroll_offset += speed * delta

	# Keep scroll_offset within one cycle to prevent large numbers
	if scroll_offset >= CYCLE_HEIGHT:
		scroll_offset = fmod(scroll_offset, CYCLE_HEIGHT)

	# Update environment positions - scenes scroll DOWN (Y increases)
	# As scroll_offset increases, environments move downward (positive Y)
	# Scenes appear from top and scroll downward seamlessly
	for i in range(environments.size()):
		var base_y = -i * SPACING  # Negative initial position (above viewport)
		var new_y = base_y + scroll_offset  # ADD to scroll downward
		environments[i].position.y = new_y

		# Ensure environment is visible when in viewport range [0, 1080]
		# Account for environment height ~1100px
		var should_be_visible = (new_y + SCENE_HEIGHT > 0) and (new_y < SCREEN_HEIGHT)
		if environments[i].visible != should_be_visible:
			environments[i].visible = should_be_visible

func get_current_phase() -> int:
	if scroll_offset < 1080.0:
		return 1  # Empty Road
	elif scroll_offset < 2160.0:
		return 2  # Pedestrians
	else:
		return 3  # Signal

func get_scroll_offset() -> float:
	return scroll_offset
