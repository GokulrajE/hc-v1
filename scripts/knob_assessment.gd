extends Node2D

var knob_1_angle_label: Label
var knob_1_title: Label
var status_label: Label
var back_button: Button
var save_button: Button
var start_button: Button
var stop_button: Button
var redo_button: Button
var min_label: Label
var max_label: Label
var current_label: Label

var knob_progress_cw: TextureProgressBar
var knob_progress_ccw: TextureProgressBar
var needle : Sprite2D
var reach_count_label: Label
var reaching_timer_label: Label
var flash_timer: float = 0.0
var pulse_time: float = 0.0
var target_dot_max: Sprite2D = null
var target_dot_min: Sprite2D = null

var min_angle = 0.0
var max_angle = 0.0
var current_angle = 0.0
var selected_knob = ""
var current_mechanism = null

const MAX_ANGLE_RANGE = 360.0

# Step 1 validation limits
const STEP1_MIN_LIMIT = 10.0
const STEP1_MAX_LIMIT = 10.0

# Assessment flow states
enum AssessmentStep { STEP1_VALIDATION, STEP2_AROM, STEP3_REACHING }
var current_step = AssessmentStep.STEP1_VALIDATION
var step1_crossed_min = false
var step1_crossed_max = false

# Step 2 AROM tracking
var arom_min = 0.0
var arom_max = 0.0

# Step 3 reaching test
var reaching_timer = 0.0
var reach_count = 0
var last_reached_min = false
var last_reached_max = false
var step3_complete = false
const REACHING_TIME_LIMIT = 60.0
const REQUIRED_REACHES = 5

func _ready() -> void:
	knob_1_title = get_node_or_null("knob_1_title")
	knob_1_angle_label = get_node_or_null("knob_1_angle_label")
	status_label = get_node_or_null("status_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	start_button = get_node_or_null("start_button")
	stop_button = get_node_or_null("stop_button")

	min_label = get_node_or_null("min_max_container/min_label")
	max_label = get_node_or_null("min_max_container/max_label")
	current_label = get_node_or_null("min_max_container/current_label")

	knob_progress_cw = get_node_or_null("knob_2_progress/knob_2_progress_cw")
	knob_progress_ccw = get_node_or_null("knob_2_progress/knob_2_progress_ccw")
	needle = get_node_or_null("knob_2_progress/needle")
	reach_count_label = get_node_or_null("reach_count")
	reaching_timer_label = get_node_or_null("reaching_timer_display")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.visible = false

	if stop_button:
		stop_button.pressed.connect(_on_stop_pressed)
		stop_button.visible = false

	redo_button = get_node_or_null("redo_button")
	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)
		redo_button.visible = false

	if HCcomm:
		# Disconnect if already connected to prevent duplicate signal error
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)
		# HCcomm.device_connected.connect(_on_device_connected)
		# HCcomm.device_disconnected.connect(_on_device_disconnected)

	selected_knob = Appdata.selected_mechanism.name
	print("KnobAssessment: Selected mechanism - %s" % selected_knob)
	_start_arom_raw_logging()
	_update_title()
	# _update_status()
	_update_step1_display()


func _update_title() -> void:
	if knob_1_title:
		knob_1_title.text = selected_knob

func _get_current_angle() -> float:
	match selected_knob:
		"KNOB":
			return HCcomm.angle_2
		"FINE KNOB":
			return HCcomm.angle_4
		"KEY KNOB":
			return HCcomm.angle_3
		_:
			return 0.0

func _on_device_data_received() -> void:
	current_angle = _get_current_angle()

	if knob_1_angle_label:
		knob_1_angle_label.text = "%.2f°" % current_angle

	if current_label:
		current_label.text = "Current: %.2f°" % current_angle

	match current_step:
		AssessmentStep.STEP1_VALIDATION:
			_process_step1()
		AssessmentStep.STEP2_AROM:
			_process_step2()
		AssessmentStep.STEP3_REACHING:
			_process_step3()

	_update_knob_progress()
	_update_needle_rotation()

func _update_step1_display() -> void:
	if min_label:
		min_label.text = "Min Limit: -%.2f°" % STEP1_MIN_LIMIT
	if max_label:
		max_label.text = "Max Limit: %.2f°" % STEP1_MAX_LIMIT
	if status_label:
		status_label.text = "STEP 1: Validation - Cross both limits to proceed"

func _process_step1() -> void:
	min_angle = STEP1_MIN_LIMIT
	max_angle = STEP1_MAX_LIMIT
	if current_angle < -STEP1_MIN_LIMIT:
		step1_crossed_min = true
	if current_angle > STEP1_MAX_LIMIT:
		step1_crossed_max = true

	if step1_crossed_min and step1_crossed_max:
		_complete_step1()

func _complete_step1() -> void:
	if status_label:
		status_label.text = "✓ Step 1 Complete! Click START to begin AROM Assessment"
	if start_button:
		start_button.visible = true
	min_angle = 0.0
	max_angle = 0.0
	print("KnobAssessment: Step 1 passed! Waiting for user to click START")

func _on_start_pressed() -> void:
	if start_button:
		start_button.visible = false
	if stop_button:
		stop_button.visible = true
	if redo_button:
		redo_button.visible = true
	min_angle = current_angle
	max_angle = current_angle
	current_step = AssessmentStep.STEP2_AROM
	if status_label:
		status_label.text = "STEP 2: AROM Assessment - Move knob through full range, then click STOP or REDO"
	print("KnobAssessment: Started AROM Assessment (Step 2)")

func _advance_to_step2() -> void:
	current_step = AssessmentStep.STEP2_AROM
	min_angle = 0.0
	max_angle = 0.0
	arom_min = 0.0
	arom_max = 0.0
	if status_label:
		status_label.text = "STEP 2: AROM Assessment - Move through full range"
	print("KnobAssessment: Advancing to Step 2 - AROM Assessment")

func _process_step2() -> void:
	if current_angle < min_angle:
		min_angle = current_angle
	if current_angle > max_angle:
		max_angle = current_angle

	if min_label:
		min_label.text = "Min: %.2f°" % min_angle
	if max_label:
		max_label.text = "Max: %.2f°" % max_angle

func _on_stop_pressed() -> void:
	if stop_button:
		stop_button.visible = false
	_advance_to_step3()

func _on_redo_pressed() -> void:
	min_angle = current_angle
	max_angle = current_angle

	if status_label:
		status_label.text = "STEP 2: AROM Assessment - Move knob through full range, then click STOP or REDO"
	if min_label:
		min_label.text = "Min: 0.00°"
	if max_label:
		max_label.text = "Max: 0.00°"
	print("KnobAssessment: Redo initiated - Restarting AROM Assessment (Step 2)")

func _advance_to_step3() -> void:
	current_step = AssessmentStep.STEP3_REACHING
	arom_min = min_angle
	arom_max = max_angle
	reaching_timer = 0.0
	reach_count = 0
	last_reached_min = false
	last_reached_max = false
	pulse_time = 0.0
	if stop_button:
		stop_button.visible = false
	if redo_button:
		redo_button.visible = false
	if status_label:
		status_label.text = "STEP 3: Reaching Validation - Reach min/max 5 times in 60 seconds"
	if min_label:
		min_label.text = "AROM Min: %.2f°" % arom_min
	if max_label:
		max_label.text = "AROM Max: %.2f°" % arom_max

	# Show reach count label and create indicator dots
	if reach_count_label:
		reach_count_label.visible = true
		reach_count_label.text = "1"
		reach_count_label.add_theme_color_override(
	"font_color",
	Color(0.1, 0.15, 0.3, 1)
)

	# Create pulsing dots at arc tips (positioned outside the progress bar)
	var circle_tex = load("res://sprites/Circle Filled.png")
	var knob_node = get_node_or_null("knob_2_progress")
	if knob_node and circle_tex:
		target_dot_max = Sprite2D.new()
		target_dot_max.texture = circle_tex
		target_dot_max.scale = Vector2(0.09, 0.09)
		target_dot_max.position = Vector2(137, 137) + Vector2(
			cos(deg_to_rad(-90.0 + arom_max)), sin(deg_to_rad(-90.0 + arom_max))) * 130.0
		knob_node.add_child(target_dot_max)

		target_dot_min = Sprite2D.new()
		target_dot_min.texture = circle_tex
		target_dot_min.scale = Vector2(0.09, 0.09)
		target_dot_min.position = Vector2(137, 137) + Vector2(
			cos(deg_to_rad(-90.0 - abs(arom_min))), sin(deg_to_rad(-90.0 - abs(arom_min)))) * 150.0
		knob_node.add_child(target_dot_min)

	print("KnobAssessment: Step 2 complete! AROM: %.2f° to %.2f°" % [arom_min, arom_max])

func _process_step3() -> void:
	if step3_complete:
		return

	var at_min = current_angle <= arom_min
	var at_max = current_angle >= arom_max

	if at_min and not last_reached_min:
		last_reached_min = true
		last_reached_max = false
	elif at_max and not last_reached_max:
		last_reached_max = true
		last_reached_min = false
		reach_count += 1
		# Trigger needle flash on reach
		flash_timer = 0.3
		if needle:
			needle.modulate = Color(1.5, 1.5, 1.5, 1)

	if current_label:
		current_label.text = "Reaches: %d/%d | Time: %.2f s" % [reach_count, REQUIRED_REACHES, reaching_timer]

	if reach_count >= REQUIRED_REACHES:
		_complete_step3()
	elif reaching_timer >= REACHING_TIME_LIMIT:
		_complete_step3()

func _complete_step3() -> void:
	step3_complete = true
	if stop_button:
		stop_button.visible = false
	if redo_button:
		redo_button.visible = false
	if status_label:
		if reach_count >= REQUIRED_REACHES and reaching_timer <= REACHING_TIME_LIMIT:
			status_label.text = "✓ Assessment Complete! Reaches: %d in %.2f seconds - Click SAVE" % [reach_count, reaching_timer]
		else:
			status_label.text = "Time expired. Reaches: %d/%d - Click SAVE to submit" % [reach_count, REQUIRED_REACHES]
	if save_button:
		save_button.visible = true

	# Hide timer and remove indicator dots
	if reach_count_label:
		reach_count_label.visible = false
	if target_dot_max:
		target_dot_max.queue_free()
		target_dot_max = null
	if target_dot_min:
		target_dot_min.queue_free()
		target_dot_min = null
	# Restore bar colors
	if knob_progress_cw:
		knob_progress_cw.modulate = Color(1, 1, 1, 1)
	if knob_progress_ccw:
		knob_progress_ccw.modulate = Color(1, 1, 1, 1)

	print("KnobAssessment: Step 3 complete! Reaches: %d in %.2f seconds" % [reach_count, reaching_timer])

func _update_min_max() -> void:
	if current_angle < min_angle:
		min_angle = current_angle
	if current_angle > max_angle:
		max_angle = current_angle

	if min_label and current_step == AssessmentStep.STEP2_AROM:
		min_label.text = "Min: %.2f°" % min_angle
	if max_label and current_step == AssessmentStep.STEP2_AROM:
		max_label.text = "Max: %.2f°" % max_angle

func _update_knob_progress() -> void:
	if not knob_progress_cw or not knob_progress_ccw:
		return
	knob_progress_cw.radial_fill_degrees = max_angle
	knob_progress_ccw.radial_fill_degrees = abs(min_angle)

	if current_step != AssessmentStep.STEP3_REACHING:
		knob_progress_cw.modulate = Color(1, 1, 1, 1)
		knob_progress_ccw.modulate = Color(1, 1, 1, 1)
		return

	var near = 5.0
	var going_to_max = last_reached_min
	var pulse = 0.5 + 0.5 * sin(pulse_time * 6.0)

	# CW bar (max side)
	if current_angle >= arom_max:
		knob_progress_cw.modulate = Color(0.878, 0.87, 0.291, 1.0)
	elif going_to_max and current_angle >= arom_max - near:
		knob_progress_cw.modulate = Color(1, 1, 0.2 + pulse * 0.2, 1)
	elif going_to_max:
		knob_progress_cw.modulate = Color(1.0, 0.9 + pulse * 0.1, 0.0, 1)
	else:
		knob_progress_cw.modulate = Color(1.637, 1.165, 0.0, 1.0)

	# CCW bar (min side)
	if current_angle <= arom_min:
		knob_progress_ccw.modulate = Color(0.878, 0.87, 0.291, 1.0)
	elif not going_to_max and current_angle <= arom_min + near:
		knob_progress_ccw.modulate = Color(1, 1, 0.2 + pulse * 0.2, 1)
	elif not going_to_max:
		knob_progress_ccw.modulate = Color(1.0, 0.9 + pulse * 0.1, 0.0, 1)
	else:
		knob_progress_ccw.modulate = Color(1.637, 1.165, 0.0, 1.0)

	# Pulse the active indicator dot; dim the inactive one
	if target_dot_max and target_dot_min:
		var dot_scale = 0.065 + pulse * 0.035
		if going_to_max:
			target_dot_max.scale = Vector2(dot_scale, dot_scale)
			target_dot_max.modulate = Color(0.2, 0.8, 1, 0.8 + pulse * 0.2)
			target_dot_min.scale = Vector2(0.055, 0.055)
			target_dot_min.modulate = Color(0.21, 0.129, 0.069, 0.3)
			# Position reach count label over active (max) dot
			if reach_count_label:
				reach_count_label.global_position = get_node_or_null("knob_2_progress").global_position + target_dot_max.position - Vector2(20, 20)
		else:
			target_dot_min.scale = Vector2(dot_scale, dot_scale)
			target_dot_min.modulate = Color(0.2, 0.8, 1, 0.8 + pulse * 0.2)
			target_dot_max.scale = Vector2(0.055, 0.055)
			target_dot_max.modulate = Color(0.21, 0.129, 0.069, 0.3)
			# Position reach count label over active (min) dot
			if reach_count_label:
				reach_count_label.global_position = get_node_or_null("knob_2_progress").global_position + target_dot_min.position - Vector2(20, 20)

func _update_needle_rotation() -> void:
	if not needle:
		return
	needle.rotation = deg_to_rad(current_angle)

# func _on_device_connected() -> void:
# 	_update_status()

# func _on_device_disconnected() -> void:
# 	_update_status()

# func _update_status() -> void:
# 	if status_label:
# 		if HCcomm and HCcomm.device_is_connected:
# 			status_label.text = "Device Status: CONNECTED - Real-time Monitoring Active"
# 		else:
# 			status_label.text = "Device Status: NOT CONNECTED - Waiting for device..."


func _start_arom_raw_logging() -> void:
	# Start AROM raw data logging
	AppDataTrial.start_arom_raw_data_logging()
	print("KnobAssessment: Started AROM raw data logging for %s" % Appdata.selected_mechanism.name)

func _physics_process(_delta: float) -> void:
	var dt = get_physics_process_delta_time()
	if current_step == AssessmentStep.STEP3_REACHING:
		if not step3_complete:
			reaching_timer += dt
		pulse_time += dt

		# Update reach count display
		if reach_count_label:
			reach_count_label.text = "%d" % (reach_count)

		if reaching_timer_label:
			reaching_timer_label.text = "Time: %d s" % int(reaching_timer)

		if status_label:
			status_label.text = "Reaches: %d/%d | Time: %d/60 s" % [reach_count, REQUIRED_REACHES, int(reaching_timer)]

	# Needle flash decay
	if flash_timer > 0.0:
		flash_timer -= dt
		if flash_timer <= 0.0 and needle:
			needle.modulate = Color(1, 1, 1, 1)

func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("KnobAssessment: Mechanism not initialized")
		if status_label:
			status_label.text = "Error: Mechanism not initialized. Cannot save."
		return

	# Stop AROM raw data logging and write to file
	AppDataTrial.stop_arom_raw_data_logging()

	# Set AROM values from step 2 assessment
	Appdata.selected_mechanism.set_new_arom_values(arom_min, arom_max, float(int(reaching_timer)))

	# Save assessment data
	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! AROM: %.2f° to %.2f° | Reaches: %d in %d s" % [arom_min, arom_max, reach_count, int(reaching_timer)]
		print("KnobAssessment: Assessment saved successfully for %s - Time: %d s" % [selected_knob, int(reaching_timer)])
		print("🎮 Navigating to game launcher...")
		_cleanup()
		await get_tree().create_timer(1.5).timeout
		# Navigate to game launcher after AROM assessment complete
		get_tree().change_scene_to_file("res://scenes/safecrossing/sc_game.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("KnobAssessment: Failed to save assessment data for %s" % selected_knob)

func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _cleanup() -> void:
	# Disconnect from signals to prevent errors when re-entering scene
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))

func _exit_tree() -> void:
	_cleanup()
