extends Node2D

var grip_progress: ProgressBar
var grip_value: Label
var back_button: Button
var save_button: Button
var status_label: Label
var threshold_line: Line2D
var counter_label: Label
var set_threshold_button: Button
var redo_button: Button
var timer_label: Label

var grip_value_current: float = 0.0
var grip_max: float = 0.0
var grip_threshold: float = 0.0
var current_mechanism = null

# Assessment states
enum AssessmentStep { capture_max, validate_threshold }
var current_step = AssessmentStep.capture_max
var threshold_reach_count: int = 0
var released: bool = true

# Timer variables
var timer_started: bool = false
var timer_elapsed: float = 0.0
var reaching_time: float = 0.0
const TIMER_DURATION: float = 60.0

func _ready() -> void:
	grip_progress = get_node_or_null("grip_progress")
	grip_value = get_node_or_null("grip_value")
	back_button = get_node_or_null("back_button")
	status_label = get_node_or_null("status_label")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Create counter label if it doesn't exist
	if not has_node("counter_label"):
		counter_label = Label.new()
		counter_label.name = "counter_label"
		add_child(counter_label)
		counter_label.position = Vector2(1400, 500)
		counter_label.add_theme_font_size_override("font_size", 40)
	else:
		counter_label = get_node_or_null("counter_label")

	# Create threshold line if it doesn't exist
	if not has_node("threshold_line"):
		threshold_line = Line2D.new()
		threshold_line.name = "threshold_line"
		add_child(threshold_line)
		threshold_line.width = 3.0
		threshold_line.default_color = Color.YELLOW
	else:
		threshold_line = get_node_or_null("threshold_line")

	# Create set threshold button
	if not has_node("set_threshold_button"):
		set_threshold_button = Button.new()
		set_threshold_button.name = "set_threshold_button"
		add_child(set_threshold_button)
		set_threshold_button.position = Vector2(650, 950)
		set_threshold_button.size = Vector2(200, 70)
		set_threshold_button.text = "Set Threshold"
		set_threshold_button.add_theme_font_size_override("font_size", 30)
		set_threshold_button.visible = false
	else:
		set_threshold_button = get_node_or_null("set_threshold_button")

	if set_threshold_button:
		set_threshold_button.pressed.connect(_on_set_threshold_pressed)

	# Create redo button
	if not has_node("redo_button"):
		redo_button = Button.new()
		redo_button.name = "redo_button"
		add_child(redo_button)
		redo_button.position = Vector2(950, 950)
		redo_button.size = Vector2(200, 70)
		redo_button.text = "Redo"
		redo_button.add_theme_font_size_override("font_size", 30)
		redo_button.visible = false
	else:
		redo_button = get_node_or_null("redo_button")

	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)

	# Create save button if it doesn't exist
	if not has_node("save_button"):
		save_button = Button.new()
		save_button.name = "save_button"
		add_child(save_button)
		save_button.position = Vector2(1350, 950)
		save_button.size = Vector2(200, 70)
		save_button.text = "Save Assessment"
		save_button.add_theme_font_size_override("font_size", 30)
		save_button.visible = false
	else:
		save_button = get_node_or_null("save_button")

	if save_button:
		save_button.pressed.connect(_on_save_pressed)

	# Create timer label if it doesn't exist
	if not has_node("timer_label"):
		timer_label = Label.new()
		timer_label.name = "timer_label"
		add_child(timer_label)
		timer_label.position = Vector2(1400, 100)
		timer_label.add_theme_font_size_override("font_size", 50)
		timer_label.text = "60"
	else:
		timer_label = get_node_or_null("timer_label")

	if HCcomm:
		# Disconnect if already connected to prevent duplicate signal error
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)

	print("GripAssessment: Started for Grip Force Assessment")
	_start_arom_raw_logging()
	_update_display()

func _process(delta: float) -> void:
	if timer_started:
		timer_elapsed += delta
		var remaining_time = TIMER_DURATION - timer_elapsed

		if timer_label:
			if remaining_time > 0:
				timer_label.text = "%.1f" % remaining_time
				timer_label.add_theme_color_override("font_color", Color.WHITE)
			else:
				timer_label.text = "0.0"
				timer_label.add_theme_color_override("font_color", Color.RED)
				_on_timer_expired()

func _get_current_grip_value() -> float:
	return HCcomm.get_total_force()

func _on_device_data_received() -> void:
	grip_value_current = _get_current_grip_value()

	if grip_value:
		grip_value.text = "Grip: %.1f kg" % grip_value_current

	match current_step:
		AssessmentStep.capture_max:
			_handle_capture_max_step()
		AssessmentStep.validate_threshold:
			_handle_validate_threshold_step()

	_update_progress()

func _handle_capture_max_step() -> void:
	# Track maximum grip force
	if grip_value_current > grip_max:
		grip_max = grip_value_current

func _handle_validate_threshold_step() -> void:
	# Only count if we haven't reached 5 yet
	if threshold_reach_count < 5:
		# Check if user reached the 10% threshold
		if grip_value_current >= grip_threshold:
			if released:
				# Transitioned from below to above threshold
				threshold_reach_count += 1
				released = false
				print("GripAssessment: Threshold reached %d/5 times" % threshold_reach_count)
				_update_counter_label()

				# Check if all 5 repetitions completed
				if threshold_reach_count >= 5:
					reaching_time = timer_elapsed
					timer_started = false
					save_button.visible = true
					redo_button.visible = false
					_update_display()
					print("GripAssessment: 5 repetitions reached in %.2f seconds" % reaching_time)
		else:
			released = true

func _update_display() -> void:
	if status_label:
		match current_step:
			AssessmentStep.capture_max:
				status_label.text = "STEP 1: Squeeze handle with MAXIMUM force to establish baseline"
				set_threshold_button.visible = grip_max > 0
				save_button.visible = false
				redo_button.visible = false
			AssessmentStep.validate_threshold:
				status_label.text = "STEP 2: Reach the yellow line (%.1f N) - %d / 5 times" % [grip_threshold, threshold_reach_count]
				save_button.visible = (threshold_reach_count >= 5)
				redo_button.visible = (threshold_reach_count < 5)

func _update_counter_label() -> void:
	if counter_label:
		counter_label.text = "Threshold Reaches: %d / 5" % threshold_reach_count
		if threshold_reach_count >= 5:
			counter_label.add_theme_color_override("font_color", Color.GREEN)
			counter_label.text = "✓ Threshold Reaches: 5 / 5"
		else:
			counter_label.add_theme_color_override("font_color", Color.WHITE)

	# Also update status label with counter progress
	if status_label:
		status_label.text = "STEP 2: Reach the yellow line (%.1f N) - %d / 5 times" % [grip_threshold, threshold_reach_count]

func _update_progress() -> void:
	if grip_progress:
		grip_progress.value = float(grip_value_current)

	# Draw threshold line when in validation step
	if current_step == AssessmentStep.validate_threshold and grip_progress:
		_draw_threshold_line()

	# Transition to validation step when user releases after capturing max
	if current_step == AssessmentStep.capture_max and grip_max > 1 and grip_value_current <= 1:
		_transition_to_validation()

func _transition_to_validation() -> void:
	grip_threshold = grip_max * 0.4
	current_step = AssessmentStep.validate_threshold
	threshold_reach_count = 0
	released = true
	timer_elapsed = 0.0
	timer_started = true
	reaching_time = 0.0
	_update_counter_label()
	_update_display()
	print("GripAssessment: Transitioning to validation step. Threshold: %.1f N (10%% of %.1f N)" % [grip_threshold, grip_max])
	print("GripAssessment: Max Force: %.1f N, Bar Max: %.1f, Bar Width: %.1f" % [grip_max, grip_progress.max_value, grip_progress.size.x])
	print("GripAssessment: 60-second timer started")

func _draw_threshold_line() -> void:
	if not threshold_line or not grip_progress:
		return

	# Calculate where the threshold value appears on the progress bar
	var bar_width = grip_progress.size.x
	var bar_height = grip_progress.size.y
	var bar_rect_position = grip_progress.get_global_rect().position
	var bar_min = grip_progress.min_value
	var bar_max = grip_progress.max_value

	# Position based on threshold value (bar fills from bottom to top, so invert Y calculation)
	var value_percentage = (grip_threshold - bar_min) / (bar_max - bar_min)
	var threshold_y = (bar_rect_position.y + bar_height) - (value_percentage * bar_height)

	print("GripAssessment: Drawing line - Bar Range: %.1f-%.1f, Threshold Value: %.1f, Percentage: %.2f%%, Threshold Y: %.1f" % [bar_min, bar_max, grip_threshold, value_percentage * 100, threshold_y])

	# Draw horizontal line at threshold value position (full width)
	threshold_line.clear_points()
	threshold_line.add_point(Vector2(bar_rect_position.x, threshold_y))
	threshold_line.add_point(Vector2(bar_rect_position.x + bar_width, threshold_y))

func _start_arom_raw_logging() -> void:
	AppDataTrial.start_arom_raw_data_logging()
	print("GripAssessment: Started AROM raw data logging for Grip Force")

func _on_timer_expired() -> void:
	if threshold_reach_count < 5:
		timer_started = false
		if status_label:
			status_label.text = "✗ Time's up! You reached %d/5 times. Click Redo to try again." % threshold_reach_count
		redo_button.visible = true
		save_button.visible = false
		print("GripAssessment: Timer expired. Only reached %d/5 repetitions" % threshold_reach_count)

func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("GripAssessment: Mechanism not initialized")
		if status_label:
			status_label.text = "Error: Mechanism not initialized. Cannot save."
		return

	# Stop AROM raw data logging
	AppDataTrial.stop_arom_raw_data_logging()

	# Set AROM values: min = 0.0 (always), max = grip_max force, reach_time = time taken
	Appdata.selected_mechanism.set_new_arom_values(0.0, grip_max, reaching_time)

	# Save assessment data
	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! Grip Force: 0.0 N to %.1f N (Time: %.2f s)" % [grip_max, reaching_time]
		print("GripAssessment: Assessment saved successfully for Grip Force (Time: %.2f s)" % reaching_time)
		print("🎮 Navigating to game launcher...")
		_cleanup()
		# await get_tree().create_timer(1.5).timeout
		# Navigate to game launcher after AROM assessment complete
		get_tree().change_scene_to_file("res://scenes/game_selection.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("GripAssessment: Failed to save assessment data for Grip Force")

func _on_set_threshold_pressed() -> void:
	if grip_max <= 0:
		if status_label:
			status_label.text = "Error: No maximum force recorded. Squeeze handle first."
		return

	_transition_to_validation()
	set_threshold_button.visible = false
	print("GripAssessment: Set Threshold button pressed. Max: %.1f N, Threshold: %.1f N" % [grip_max, grip_threshold])

func _on_redo_pressed() -> void:
	# Reset entire process back to Step 1
	current_step = AssessmentStep.capture_max
	grip_max = 0.0
	grip_threshold = 0.0
	threshold_reach_count = 0
	released = true
	timer_started = false
	timer_elapsed = 0.0
	reaching_time = 0.0

	# Hide all action buttons
	set_threshold_button.visible = false
	redo_button.visible = false
	save_button.visible = false

	# Clear threshold line
	if threshold_line:
		threshold_line.clear_points()

	# Reset timer display
	if timer_label:
		timer_label.text = "60"
		timer_label.add_theme_color_override("font_color", Color.WHITE)

	_update_counter_label()
	_update_display()
	print("GripAssessment: Redo button pressed. Restarting from Step 1.")

func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _cleanup() -> void:
	# Disconnect from signals to prevent errors when re-entering scene
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))

	# Stop AROM logging if still active
	if timer_started:
		timer_started = false

func _exit_tree() -> void:
	_cleanup()
