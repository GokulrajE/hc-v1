extends Node2D

var grip_progress: ProgressBar
var grip_value: Label
var back_button: Button
var save_button: Button
var status_label: Label
var threshold_line: Line2D
var continue_button: Button
var redo_button: Button
var counter_label: Label
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
var baseline_captured: bool = false

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
	counter_label = get_node_or_null("rep_count")
	timer_label = get_node_or_null("timer")
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


	# Create threshold line if it doesn't exist
	if not has_node("threshold_line"):
		threshold_line = Line2D.new()
		threshold_line.name = "threshold_line"
		add_child(threshold_line)
		threshold_line.width = 3.0
		threshold_line.default_color = Color.YELLOW
	else:
		threshold_line = get_node_or_null("threshold_line")

	continue_button = get_node_or_null("continue_button")
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	redo_button = get_node_or_null("redo_button")
	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)

	save_button = get_node_or_null("save_button")
	if save_button:
		save_button.pressed.connect(_on_save_pressed)


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
				timer_label.text = "%.0f" % remaining_time
				
			else:
				timer_label.text = "0"
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
				ScAudioManager.play_asmnt_reach()
				print("GripAssessment: Threshold reached %d/5 times" % threshold_reach_count)
				_update_counter_label()

				# Check if all 5 repetitions completed
				if threshold_reach_count >= 5:
					reaching_time = timer_elapsed
					timer_started = false
					save_button.visible = true
					redo_button.visible = false
					ScAudioManager.play_asmnt_complete()
					_update_display()
					print("GripAssessment: 5 repetitions reached in %.2f seconds" % reaching_time)
		else:
			released = true

func _update_display() -> void:
	if status_label:
		match current_step:
			AssessmentStep.capture_max:
				if timer_label: timer_label.visible = false
				if counter_label: counter_label.visible = false
				status_label.text = "STEP 1: Squeeze handle with MAXIMUM force to establish baseline"
				if continue_button:
					continue_button.visible = baseline_captured
				if redo_button:
					redo_button.visible = baseline_captured
				save_button.visible = false
			AssessmentStep.validate_threshold:
				if timer_label:
					timer_label.visible = true
					if threshold_reach_count == 0:
						timer_label.text = "%.0f" % TIMER_DURATION
				if counter_label:
					counter_label.visible = true
					if threshold_reach_count == 0:
						counter_label.text = "Reach count: 0 / 5"
				status_label.text = "STEP 2: Reach the yellow line (%.1f N) - %d / 5 times" % [grip_threshold, threshold_reach_count]
				save_button.visible = (threshold_reach_count >= 5)
				redo_button.visible = (threshold_reach_count < 5)

func _update_counter_label() -> void:
	if counter_label:
		counter_label.text = "Reach count: %d / 5" % threshold_reach_count
		if threshold_reach_count >= 5:
			counter_label.text = "✓ Reach count : 5 / 5"
		
	# Also update status label with counter progress
	if status_label:
		status_label.text = "STEP 2: Reach the yellow line (%.1f N) - %d / 5 times" % [grip_threshold, threshold_reach_count]

func _update_progress() -> void:
	if grip_progress:
		grip_progress.value = float(grip_value_current)

	if grip_progress and (current_step == AssessmentStep.validate_threshold or baseline_captured):
		_draw_threshold_line()

	if current_step == AssessmentStep.capture_max and not baseline_captured \
			and grip_max > 1.0 and grip_value_current <= 1.0:
		baseline_captured = true
		grip_threshold = grip_max * 0.4
		_update_display()


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
		var handle_rom := ROM.new("HANDLE", true)
		if handle_rom.is_arom_set() or Appdata.reassessing:
			Appdata.reassessing = false
			get_tree().change_scene_to_file("res://scene/game_selection.tscn")
		else:
			get_tree().change_scene_to_file("res://scene/mechanism.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("GripAssessment: Failed to save assessment data for Grip Force")

func _on_continue_pressed() -> void:
	ScAudioManager.play_asmnt_btn()
	if grip_max <= 0:
		if status_label:
			status_label.text = "Error: No maximum force recorded. Squeeze handle first."
		return

	_transition_to_validation()
	continue_button.visible = false
	print("GripAssessment: Continue button pressed. Max: %.1f N, Threshold: %.1f N" % [grip_max, grip_threshold])

func _on_redo_pressed() -> void:
	
	current_step = AssessmentStep.capture_max
	grip_max = 0.0
	grip_threshold = 0.0
	threshold_reach_count = 0
	released = true
	baseline_captured = false
	timer_started = false
	timer_elapsed = 0.0
	reaching_time = 0.0

	# Hide all action buttons
	continue_button.visible = false
	redo_button.visible = false
	save_button.visible = false

	# Clear threshold line
	if threshold_line:
		threshold_line.clear_points()

	# Reset timer display
	if timer_label:
		timer_label.text = "60"
		
	_update_counter_label()
	_update_display()
	print("GripAssessment: Redo button pressed. Restarting from Step 1.")

func _on_back_pressed() -> void:
	_cleanup()
	if Appdata.reassessing:
		Appdata.reassessing = false
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
		return
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
