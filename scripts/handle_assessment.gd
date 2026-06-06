extends Node2D

var grip_title: Label
var grip_angle_label: Label
var status_label: Label
var back_button: Button
var save_button: Button
var start_button: Button
var stop_button: Button
var redo_button: Button
var min_label: Label
var max_label: Label
var current_label: Label
var angle_gauge: Control
var reach_count_label: Label
var reaching_timer_label: Label

var min_angle = 0.0
var max_angle = 0.0
var current_angle = 0.0
var grip_value_current = 0.0
var current_mechanism = null
var flash_timer: float = 0.0
var pulse_time: float = 0.0
var target_dot_max: Sprite2D = null
var target_dot_min: Sprite2D = null

const MAX_ANGLE_RANGE = 110.0
const REACHING_TIME_LIMIT = 60.0
const REQUIRED_REACHES = 5

# Assessment flow states
enum AssessmentStep { STEP1_COMFORTABLE, STEP2_AROM, STEP3_REACHING }
var current_step = AssessmentStep.STEP1_COMFORTABLE
var start_point = 0.0
var arom_min = 0.0
var arom_max = 0.0
var reaching_timer = 0.0
var reach_count = 0
var last_reached_min = false
var last_reached_max = false
var step3_complete = false

func _ready() -> void:
	grip_angle_label = get_node_or_null("handle_angle")
	status_label = get_node_or_null("status_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	start_button = get_node_or_null("start_button")
	stop_button = get_node_or_null("stop_button")
	redo_button = get_node_or_null("redo_button")

	min_label = get_node_or_null("min_max_container/min_label")
	max_label = get_node_or_null("min_max_container/max_label")
	current_label = get_node_or_null("min_max_container/current_label")
	reach_count_label = get_node_or_null("reach_count")
	reaching_timer_label = get_node_or_null("reaching_timer_display")

	angle_gauge = get_node_or_null("gauge_container/angle_gauge")

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

	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)
		redo_button.visible = false

	if HCcomm:
		# Disconnect if already connected to prevent duplicate signal error
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)

	print("HandleAssessment: Started for Handle mechanism")
	_start_arom_raw_logging()
	_update_step1_display()

func _get_current_angle() -> float:
	return HCcomm.angle_1

func _get_current_grip_value() -> float:
	return HCcomm.get_total_force()

func _on_device_data_received() -> void:
	current_angle = _get_current_angle()
	grip_value_current = _get_current_grip_value()

	if grip_angle_label:
		grip_angle_label.text = "%.2f°" % current_angle

	if current_label:
		current_label.text = "Current: %.2f°" % current_angle

	match current_step:
		AssessmentStep.STEP1_COMFORTABLE:
			_process_step1()
		AssessmentStep.STEP2_AROM:
			_process_step2()
		AssessmentStep.STEP3_REACHING:
			_process_step3()

	_update_angle_gauge()

func _update_step1_display() -> void:
	if min_label:
		min_label.text = "Min: 0°"
	if max_label:
		max_label.text = "Max: 120°"
	if status_label:
		status_label.text = "STEP 1: Select comfortable position - Click START when ready"
	if angle_gauge:
		angle_gauge.clear_shade_zones()
		angle_gauge.add_shade_zone(0.0, 0.0, Color(0.73, 0.45, 0.94, 1.0))

func _process_step1() -> void:
	if status_label:
		status_label.text = "STEP 1: Select comfortable position. Current: %.2f° - Click START when ready" % current_angle
	if start_button:
		start_button.visible = true
	

func _on_start_pressed() -> void:
	match current_step:
		AssessmentStep.STEP1_COMFORTABLE:
			start_point = current_angle
			if start_button:
				start_button.visible = false
			if stop_button:
				stop_button.visible = true
			if redo_button:
				redo_button.visible = true
			_advance_to_step2()
			print("HandGripAssessment: Step 1 complete! Start point: %.2f°" % start_point)

func _advance_to_step2() -> void:
	current_step = AssessmentStep.STEP2_AROM
	min_angle = current_angle
	max_angle = current_angle
	if status_label:
		status_label.text = "STEP 2: AROM Assessment - Move handle through full range from start point (%.2f°)" % start_point
	if min_label:
		min_label.text = "Min: --"
	if max_label:
		max_label.text = "Max: --"
	print("HandGripAssessment: Step 1 complete! Advancing to Step 2 - AROM Assessment from start point: %.2f°" % start_point)

func _process_step2() -> void:
	if current_angle < min_angle:
		min_angle = current_angle
	if current_angle > max_angle:
		max_angle = current_angle

	if min_label:
		min_label.text = "Min: %.2f°" % min_angle
	if max_label:
		max_label.text = "Max: %.2f°" % max_angle

	if angle_gauge:
		angle_gauge.set_current_angle(current_angle)
		angle_gauge.clear_shade_zones()
		angle_gauge.add_shade_zone(min_angle, max_angle, Color(0.42, 0.14, 0.61, 1.0))

func _on_stop_pressed() -> void:
	if stop_button:
		stop_button.visible = false
	_advance_to_step3()

func _on_redo_pressed() -> void:
	min_angle = current_angle
	max_angle = current_angle

	if status_label:
		status_label.text = "STEP 2: AROM Assessment - Move handle through full range, then click STOP or REDO"
	if min_label:
		min_label.text = "Min: 0.00°"
	if max_label:
		max_label.text = "Max: 0.00°"
	print("HandGripAssessment: Redo initiated - Restarting AROM Assessment (Step 2)")

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
		reach_count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	# Create pulsing dots at arc tips (positioned outside the gauge)
	var circle_tex = load("res://sprites/Circle Filled.png")
	var angle_gauge_node = angle_gauge
	if angle_gauge_node and circle_tex:
		var gauge_center = angle_gauge_node.size / 2.0
		var gauge_radius = 200.0
		var dot_radius = gauge_radius + 50.0

		target_dot_max = Sprite2D.new()
		target_dot_max.texture = circle_tex
		target_dot_max.scale = Vector2(0.09, 0.09)
		var angle_max_rad = deg_to_rad(arom_max - 180.0)
		target_dot_max.position = gauge_center + Vector2(cos(angle_max_rad), sin(angle_max_rad)) * dot_radius
		angle_gauge_node.add_child(target_dot_max)

		target_dot_min = Sprite2D.new()
		target_dot_min.texture = circle_tex
		target_dot_min.scale = Vector2(0.09, 0.09)
		var angle_min_rad = deg_to_rad(arom_min - 180.0)
		target_dot_min.position = gauge_center + Vector2(cos(angle_min_rad), sin(angle_min_rad)) * dot_radius
		angle_gauge_node.add_child(target_dot_min)

	print("HandGripAssessment: Step 2 complete! AROM: %.2f° to %.2f°" % [arom_min, arom_max])

func _process_step3() -> void:
	if step3_complete:
		return

	var at_min = current_angle <= arom_min
	var at_max = current_angle >= arom_max

	if at_min and not last_reached_min:
		last_reached_min = true
		last_reached_max = false
		flash_timer = 0.3
	elif at_max and not last_reached_max:
		last_reached_max = true
		last_reached_min = false
		reach_count += 1
		flash_timer = 0.3

	if reach_count_label:
		reach_count_label.text = "%d" % (reach_count)

	if reach_count >= REQUIRED_REACHES:
		_complete_step3()
	elif reaching_timer >= REACHING_TIME_LIMIT:
		_complete_step3()

func _complete_step3() -> void:
	step3_complete = true
	if status_label:
		if reach_count >= REQUIRED_REACHES and reaching_timer <= REACHING_TIME_LIMIT:
			status_label.text = "✓ Assessment Complete! Reaches: %d in %.2f seconds - Click SAVE" % [reach_count, reaching_timer]
		else:
			status_label.text = "Time expired. Reaches: %d/%d - Click SAVE to submit" % [reach_count, REQUIRED_REACHES]
	if save_button:
		save_button.visible = true
	if reach_count_label:
		reach_count_label.visible = false
	if target_dot_max:
		target_dot_max.queue_free()
		target_dot_max = null
	if target_dot_min:
		target_dot_min.queue_free()
		target_dot_min = null
	print("HandGripAssessment: Step 3 complete! Reaches: %d in %.2f seconds" % [reach_count, reaching_timer])

func _physics_process(_delta: float) -> void:
	var dt = get_physics_process_delta_time()
	if current_step == AssessmentStep.STEP3_REACHING:
		if not step3_complete:
			reaching_timer += dt
		pulse_time += dt

		if reach_count_label:
			reach_count_label.text = "%d" % (reach_count)

		if reaching_timer_label:
			reaching_timer_label.text = "Time: %d s" % int(reaching_timer)

		if status_label:
			status_label.text = "Reaches: %d/%d | Time: %d/60 s" % [reach_count, REQUIRED_REACHES, int(reaching_timer)]

	# Needle flash decay
	if flash_timer > 0.0:
		flash_timer -= dt

func _update_angle_gauge() -> void:
	if not angle_gauge:
		return

	angle_gauge.set_current_angle(current_angle)

	if current_step == AssessmentStep.STEP3_REACHING:
		_update_reaching_visual_feedback()

func _update_reaching_visual_feedback() -> void:
	if not angle_gauge:
		return

	var near = 5.0
	var going_to_max = last_reached_min
	var pulse = 0.5 + 0.5 * sin(pulse_time * 6.0)

	angle_gauge.clear_shade_zones()

	# Determine target zone colors
	if current_angle >= arom_max:
		# At max target - solid green
		angle_gauge.add_shade_zone(arom_min, arom_max, Color(0.2, 1, 0.4, 1))
	elif going_to_max and current_angle >= arom_max - near:
		# Near max target - yellow pulse
		var zone_color = Color(0.8 + pulse * 0.2, 0.8 + pulse * 0.2, 0.0, 1)
		angle_gauge.add_shade_zone(arom_min, arom_max, zone_color)
	elif going_to_max:
		# Going to max, far from target - orange pulse
		var zone_color = Color(0.8 + pulse * 0.2, 0.8 + pulse * 0.2, 0.0, 1)
		angle_gauge.add_shade_zone(arom_min, arom_max, zone_color)
	elif current_angle <= arom_min:
		# At min target - solid green
		angle_gauge.add_shade_zone(arom_min, arom_max, Color(0.2, 1, 0.4, 1))
	elif not going_to_max and current_angle <= arom_min + near:
		# Near min target - yellow pulse
		var zone_color = Color(0.8 + pulse * 0.2, 0.8 + pulse * 0.2, 0.0, 1)
		angle_gauge.add_shade_zone(arom_min, arom_max, zone_color)
	elif not going_to_max:
		# Going to min, far from target - orange pulse
		var zone_color = Color(0.8 + pulse * 0.2, 0.8 + pulse * 0.2, 0.0, 1)
		angle_gauge.add_shade_zone(arom_min, arom_max, zone_color)
	else:
		# Default state
		angle_gauge.add_shade_zone(arom_min, arom_max, Color(0.714, 0.161, 0.255, 1.0))

	# Pulse the active indicator dot; dim the inactive one
	if target_dot_max and target_dot_min:
		var dot_scale = 0.065 + pulse * 0.035
		if going_to_max:
			target_dot_max.scale = Vector2(dot_scale, dot_scale)
			target_dot_max.modulate = Color(0.2, 0.8, 1, 0.8 + pulse * 0.2)
			target_dot_min.scale = Vector2(0.055, 0.055)
			target_dot_min.modulate = Color(0.21, 0.129, 0.069, 0.3)
		else:
			target_dot_min.scale = Vector2(dot_scale, dot_scale)
			target_dot_min.modulate = Color(0.2, 0.8, 1, 0.8 + pulse * 0.2)
			target_dot_max.scale = Vector2(0.055, 0.055)
			target_dot_max.modulate = Color(0.21, 0.129, 0.069, 0.3)

func _start_arom_raw_logging() -> void:
	AppDataTrial.start_arom_raw_data_logging()
	print("HandleAssessment: Started AROM raw data logging for Handle")

func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("HandGripAssessment: Mechanism not initialized")
		if status_label:
			status_label.text = "Error: Mechanism not initialized. Cannot save."
		return

	AppDataTrial.stop_arom_raw_data_logging()
	Appdata.selected_mechanism.set_new_arom_values(arom_min, arom_max, float(int(reaching_timer)))

	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! AROM: %.2f° to %.2f° | Reaches: %d in %d s" % [arom_min, arom_max, reach_count, int(reaching_timer)]
		print("HandGripAssessment: Assessment saved successfully for Handle - Time: %d s" % int(reaching_timer))
		print("🎮 Navigating to game launcher...")
		_cleanup()
		await get_tree().create_timer(1.5).timeout
		# Navigate to game launcher after AROM assessment complete
		get_tree().change_scene_to_file("res://scenes/safecrossing/sc_game.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("HandGripAssessment: Failed to save assessment data for Handle")

func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _cleanup() -> void:
	# Disconnect from signals to prevent errors when re-entering scene
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))

func _exit_tree() -> void:
	_cleanup()
