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

var min_angle = 0.0
var max_angle = 0.0
var current_angle = 0.0
var grip_value_current = 0.0
var current_mechanism = null

const MAX_ANGLE_RANGE = 110.0
const STEP2_VALIDATION_LIMIT = 10.0
const REACHING_TIME_LIMIT = 60.0
const REQUIRED_REACHES = 5

# Assessment flow states
enum AssessmentStep { STEP1_COMFORTABLE, STEP2_VALIDATION, STEP3_AROM, STEP4_REACHING }
var current_step = AssessmentStep.STEP1_COMFORTABLE
var start_point = 0.0
var step2_crossed_min = false
var step2_crossed_max = false
var arom_min = 0.0
var arom_max = 0.0
var reaching_timer = 0.0
var reach_count = 0
var last_reached_min = false
var last_reached_max = false
var step4_complete = false

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
		AssessmentStep.STEP2_VALIDATION:
			_process_step2()
		AssessmentStep.STEP3_AROM:
			_process_step3()
		AssessmentStep.STEP4_REACHING:
			_process_step4()

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
			step2_crossed_min = false
			step2_crossed_max = false
			current_step = AssessmentStep.STEP2_VALIDATION

			if status_label:
				status_label.text = "STEP 2: Validation - Cross ±10° limits from %.2f°" % start_point
			if min_label:
				min_label.text = "Min: %.2f°" % (start_point - STEP2_VALIDATION_LIMIT)
			if max_label:
				max_label.text = "Max: %.2f°" % (start_point + STEP2_VALIDATION_LIMIT)
			print("HandGripAssessment: Step 1 complete! Start point: %.2f°" % start_point)
		AssessmentStep.STEP2_VALIDATION:
			if start_button:
				if step2_crossed_min and step2_crossed_max:
					_advance_to_step3()
					start_button.visible = false
			if stop_button:
				stop_button.visible = true
			if redo_button:
				redo_button.visible = true

func _process_step2() -> void:
	if current_angle < (start_point - STEP2_VALIDATION_LIMIT):
		step2_crossed_min = true
	if current_angle > (start_point + STEP2_VALIDATION_LIMIT):
		step2_crossed_max = true

	var min_limit = start_point - STEP2_VALIDATION_LIMIT
	var max_limit = start_point + STEP2_VALIDATION_LIMIT

	if angle_gauge:
		angle_gauge.set_current_angle(current_angle)
		angle_gauge.clear_shade_zones()

		# Show validation zone
		var zone_color = Color.GREEN if (step2_crossed_min and step2_crossed_max) else Color(1.0, 0.85, 0.0, 1.0)
		angle_gauge.add_shade_zone(min_limit, max_limit, zone_color)

	if status_label:
		if step2_crossed_min and step2_crossed_max:
			status_label.text = "✓ Both limits crossed! Click STOP to proceed to AROM assessment"
		elif step2_crossed_min:
			status_label.text = "✓ Crossed minimum limit (%.2f°). Now cross maximum limit (%.2f°)" % [min_limit, max_limit]
		elif step2_crossed_max:
			status_label.text = "✓ Crossed maximum limit (%.2f°). Now cross minimum limit (%.2f°)" % [max_limit, min_limit]
		else:
			status_label.text = "STEP 2: Validation - Cross ±10° limits from %.2f° (Min: %.2f° | Max: %.2f°)" % [start_point, min_limit, max_limit]

	

func _advance_to_step3() -> void:
	current_step = AssessmentStep.STEP3_AROM
	min_angle = current_angle
	max_angle = current_angle
	if stop_button:
		stop_button.visible = false
	if redo_button:
		redo_button.visible = false

	if status_label:
		status_label.text = "STEP 3: AROM Assessment - Move handle through full range from start point (%.2f°)" % start_point
	if min_label:
		min_label.text = "Min: --"
	if max_label:
		max_label.text = "Max: --"
	print("HandGripAssessment: Step 2 passed! Advancing to Step 3 - Start point: %.2f°" % start_point)

func _process_step3() -> void:
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
	_advance_to_step4()

func _on_redo_pressed() -> void:
	min_angle = current_angle
	max_angle = current_angle
	step2_crossed_min = false
	step2_crossed_max = false

	if status_label:
		status_label.text = "STEP 2: Validation - Move ±10° from starting point, then click STOP or REDO"
	if min_label:
		min_label.text = "Min Limit: %.2f°" % (start_point - STEP2_VALIDATION_LIMIT)
	if max_label:
		max_label.text = "Max Limit: %.2f°" % (start_point + STEP2_VALIDATION_LIMIT)
	print("HandGripAssessment: Redo initiated - Restarting validation (Step 2)")

func _advance_to_step4() -> void:
	current_step = AssessmentStep.STEP4_REACHING
	arom_min = min_angle
	arom_max = max_angle
	reaching_timer = 0.0
	reach_count = 0
	last_reached_min = false
	last_reached_max = false

	if status_label:
		status_label.text = "STEP 4: Reaching Test - Reach min/max 5 times in 60 seconds"
	if min_label:
		min_label.text = "AROM Min: %.2f°" % arom_min
	if max_label:
		max_label.text = "AROM Max: %.2f°" % arom_max
	if angle_gauge:
		angle_gauge.clear_shade_zones()
		angle_gauge.add_shade_zone(arom_min, arom_max, Color(0.714, 0.161, 0.255, 1.0))
	print("HandGripAssessment: Step 3 complete! AROM: %.2f° to %.2f°" % [arom_min, arom_max])

func _process_step4() -> void:
	if step4_complete:
		angle_gauge.add_shade_zone(arom_min, arom_max, Color(0.0, 0.8, 0.4, 1.0))
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

	if current_label:
		current_label.text = "Reaches: %d/%d | Time: %.1f s" % [reach_count, REQUIRED_REACHES, reaching_timer]

	if reach_count >= REQUIRED_REACHES:
		_complete_step4()
	elif reaching_timer >= REACHING_TIME_LIMIT:
		_complete_step4()

func _complete_step4() -> void:
	step4_complete = true
	if status_label:
		if reach_count >= REQUIRED_REACHES and reaching_timer <= REACHING_TIME_LIMIT:
			status_label.text = "✓ Assessment Complete! Reaches: %d in %.1f seconds - Click SAVE" % [reach_count, reaching_timer]
		else:
			status_label.text = "Time expired. Reaches: %d/%d - Click SAVE to submit" % [reach_count, REQUIRED_REACHES]
	if save_button:
		save_button.visible = true
	print("HandGripAssessment: Step 4 complete! Reaches: %d in %.1f seconds" % [reach_count, reaching_timer])

func _physics_process(_delta: float) -> void:
	if current_step == AssessmentStep.STEP4_REACHING:
		reaching_timer += get_physics_process_delta_time()

func _update_angle_gauge() -> void:
	if angle_gauge:
		angle_gauge.set_current_angle(current_angle)

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
	Appdata.selected_mechanism.set_new_arom_values(arom_min, arom_max, reaching_timer)

	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! AROM: %.2f° to %.2f° | Reaches: %d in %.1f s" % [arom_min, arom_max, reach_count, reaching_timer]
		print("HandGripAssessment: Assessment saved successfully for Handle - Time: %.1f s" % reaching_timer)
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scene/mechanism.tscn")
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
