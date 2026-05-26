extends Node2D

var status_label: Label
var distance_label: Label
var back_button: Button
var save_button: Button
var setmin_button: Button
var setmax_button: Button
var start_button: Button
var minprogressbar1: ProgressBar
var minprogressbar2: ProgressBar
var maxprogressbar1: ProgressBar
var maxprogressbar2: ProgressBar
var reach_count_label: Label
var reaching_timer_label: Label
var min_indicator_overlay: Control
var max_indicator_overlay: Control

var distance_current: float = 6.0
var distance_start: float = 6.0
var distance_min: float = 6.0
var distance_max: float = 6.0
var flash_timer: float = 0.0
var pulse_time: float = 0.0

# Moving average for sensor noise reduction
var moving_average: float = 0.0
var moving_average_counter: int = 0
const MOVING_AVERAGE_LENGTH: int = 10

# Tripod assessment states
enum AssessmentStep { SETMAX, SETMIN, REACHING, COMPLETE }
var current_step = AssessmentStep.SETMAX

# Reaching validation
var reaching_timer: float = 0.0
var reach_count: int = 1
var last_reached_min: bool = false
var last_reached_max: bool = false
var step_reaching_complete: bool = false

const MIN_DISTANCE = 2.0
const MAX_DISTANCE = 6.0
const REACHING_TIME_LIMIT = 60.0
const REQUIRED_REACHES = 5
const NEAR_THRESHOLD = 0.2

func _ready() -> void:
	status_label = get_node_or_null("status_label")
	distance_label = get_node_or_null("distance_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	setmin_button = get_node_or_null("setmin_button")
	setmax_button = get_node_or_null("setmax_button")
	start_button = get_node_or_null("start_button")
	minprogressbar1 = get_node_or_null("minProgressBarE-B/minProgressBarB-E")
	minprogressbar2 = get_node_or_null("minProgressBarE-B")
	maxprogressbar1 = get_node_or_null("maxProgressBarE-B2/maxProgressBarB-E")
	maxprogressbar2 = get_node_or_null("maxProgressBarE-B2")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	if setmax_button:
		setmax_button.pressed.connect(_on_setmax_pressed)
		setmax_button.visible = true

	if setmin_button:
		setmin_button.pressed.connect(_on_setmin_pressed)
		setmin_button.visible = false

	if start_button:
		start_button.pressed.connect(_on_start_reaching_pressed)
		start_button.visible = false

	if HCcomm:
		# Disconnect if already connected to prevent duplicate signal error
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)

	reach_count_label = get_node_or_null("timer_label")
	reaching_timer_label = get_node_or_null("reaching_timer_display")

	print("TripodAssessment: Started for Tripod Grip mechanism")
	_reset_moving_average()
	_start_arom_raw_logging()
	_update_display()

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	var dt = get_physics_process_delta_time()
	if current_step == AssessmentStep.REACHING:
		if not step_reaching_complete:
			reaching_timer += dt
		pulse_time += dt

		if reach_count_label:
			reach_count_label.text = "%d" % reach_count

		if reaching_timer_label:
			reaching_timer_label.text = "Time: %d s" % int(reaching_timer)

		if status_label:
			status_label.text = "Reaches: %d/%d | Time: %d/60 s" % [reach_count, REQUIRED_REACHES, int(reaching_timer)]

	# Flash decay
	if flash_timer > 0.0:
		flash_timer -= dt

func _on_device_data_received() -> void:
	var raw_distance = HCcomm.get_btw_distance()
	distance_current = _calculate_moving_average(raw_distance)

	match current_step:
		AssessmentStep.SETMAX:
			_update_max_bars()
		AssessmentStep.SETMIN:
			_update_min_bars()
		AssessmentStep.REACHING:
			_process_reaching()

	if distance_label:
		distance_label.text = "Distance: %.2f cm" % distance_current

func _update_min_bars() -> void:
	# Track minimum distance during compression phase
	if !setmin_button.visible:
		_update_reaching_bars()
		return  # Don't update min bars until we're in the setmin phase
	if distance_current < distance_min:
		distance_min = distance_current

	# Update min progress bars
	if minprogressbar1:
		minprogressbar1.value = distance_current
		minprogressbar1.modulate = Color(1, 1, 1, 1)
	if minprogressbar2:
		minprogressbar2.value = distance_current
		minprogressbar2.modulate = Color(1, 1, 1, 1)

func _update_max_bars() -> void:
	# Track maximum distance during recovery phase
	if distance_current > distance_max:
		distance_max = distance_current

	# Update max progress bars
	if maxprogressbar1:
		maxprogressbar1.value = distance_current
		maxprogressbar1.modulate = Color(1, 1, 1, 1)
	if maxprogressbar2:
		maxprogressbar2.value = distance_current
		maxprogressbar2.modulate = Color(1, 1, 1, 1)

func _update_reaching_bars() -> void:
	# # Update progress bars to show min/max ranges (fixed)
	# if minprogressbar1:
	# 	minprogressbar1.value = distance_min
	# 	minprogressbar1.modulate = Color(0, 0.6, 0.5, 1)

	# if minprogressbar2:
	# 	minprogressbar2.value = distance_min
	# 	minprogressbar2.modulate = Color(0, 0.6, 0.5, 1)

	# if maxprogressbar1:
	# 	maxprogressbar1.value = distance_max
	# 	maxprogressbar1.modulate = Color(0.2, 0.4, 0.6, 1)

	# if maxprogressbar2:
	# 	maxprogressbar2.value = distance_max
	# 	maxprogressbar2.modulate = Color(0.2, 0.4, 0.6, 1)

	# Update indicator line positions
	if minprogressbar1 and min_indicator_overlay:
		_update_indicator_overlay(min_indicator_overlay, minprogressbar1, distance_current)

	if maxprogressbar2 and max_indicator_overlay:
		_update_indicator_overlay(max_indicator_overlay, maxprogressbar2, distance_current)

func _update_indicator_overlay(overlay: Control, progress_bar: ProgressBar, current_value: float) -> void:
	# Calculate position based on progress bar value range
	var bar_min = progress_bar.min_value
	var bar_max = progress_bar.max_value
	var bar_range = bar_max - bar_min
	var percent = (current_value - bar_min) / bar_range if bar_range > 0 else 0.0
	percent = clamp(percent, 0.0, 1.0)

	# Position overlay to match progress bar exactly
	overlay.global_position = progress_bar.global_position
	overlay.size = progress_bar.size

	# Calculate x position for the indicator line within the overlay
	var indicator_x: float
	if progress_bar.fill_mode == 1:
		# Right to Left fill (min bar) - reverse the percentage
		indicator_x = (1.0 - percent) * progress_bar.size.x - 4
	else:
		# Left to Right fill (max bar) - normal percentage
		indicator_x = percent * progress_bar.size.x - 4

	# Store the indicator position in a custom property for the draw function
	overlay.set_meta("indicator_x", indicator_x)

	# Draw the golden yellow vertical line
	overlay.queue_redraw()

	# Connect to draw signal if not already connected
	if not overlay.is_connected("draw", Callable(self, "_on_draw_indicator")):
		overlay.draw.connect(_on_draw_indicator.bindv([overlay, progress_bar]))

func _on_draw_indicator(overlay: Control, progress_bar: ProgressBar) -> void:
	# Draw a golden yellow vertical line (8px wide)
	var line_width = 8
	var line_height = progress_bar.size.y
	var indicator_x = overlay.get_meta("indicator_x", 0.0)
	overlay.draw_rect(Rect2(indicator_x, 0, line_width, line_height), Color(1.0, 0.85, 0.0, 1.0))

func _calculate_moving_average(raw_value: float) -> float:
	moving_average_counter += 1

	if moving_average_counter > MOVING_AVERAGE_LENGTH:
		moving_average = moving_average + (raw_value - moving_average) / (MOVING_AVERAGE_LENGTH + 1)
	else:
		moving_average += raw_value
		if moving_average_counter == MOVING_AVERAGE_LENGTH:
			moving_average = moving_average / moving_average_counter

	return moving_average

func _reset_moving_average() -> void:
	moving_average = 0.0
	moving_average_counter = 0

func _update_display() -> void:
	if status_label:
		match current_step:
			AssessmentStep.SETMAX:
				status_label.text = "STEP 1: Release and expand to find maximum extension distance, then click SET MAX"
			AssessmentStep.SETMIN:
				if start_button and start_button.visible:
					status_label.text = "Ready to start reaching validation. Click START ASSESSMENT to begin"
				else:
					status_label.text = "STEP 2: Squeeze the tripod grip to find minimum compression distance, then click SET MIN"
			AssessmentStep.REACHING:
				status_label.text = "STEP 3: Reaching Validation - Touch min/max 5 times in 60 seconds"
			AssessmentStep.COMPLETE:
				status_label.text = "✓ Assessment complete! Click SAVE ASSESSMENT to store results"

func _on_setmax_pressed() -> void:
	# Store the maximum value and move to setmin phase
	distance_max = distance_current
	current_step = AssessmentStep.SETMIN
	setmax_button.visible = false
	setmin_button.visible = true
	_reset_moving_average()
	_update_display()
	print("TripodAssessment: Maximum distance set to %.2f cm - Now finding minimum" % [distance_max])

func _on_setmin_pressed() -> void:
	# Store the minimum value and show start button
	distance_min = distance_current
	setmin_button.visible = false
	if start_button:
		start_button.visible = true
	_advance_to_reaching()
	print("TripodAssessment: Minimum distance set to %.2f cm - Ready to start reaching validation" % [distance_min])

func _on_start_reaching_pressed() -> void:
	# Start the reaching validation phase
	if start_button:
		start_button.visible = false
	current_step = AssessmentStep.REACHING
	_update_display()
	print("TripodAssessment: Starting reaching validation phase")

func _advance_to_reaching() -> void:
	
	reaching_timer = 0.0
	reach_count = 0
	last_reached_min = false
	last_reached_max = false
	pulse_time = 0.0
	step_reaching_complete = false
	_reset_moving_average()

	if reach_count_label:
		reach_count_label.visible = true
		reach_count_label.z_index = 100
		reach_count_label.text = "%d" % reach_count
		reach_count_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))

	# Create indicator lines for min and max progress bars
	_create_indicator_lines()

	_update_display()
	print("TripodAssessment: Advancing to Step 3 - Reaching Validation. Range: %.2f - %.2f cm. Time limit: %.2f s" % [distance_min, distance_max, REACHING_TIME_LIMIT])

func _create_indicator_lines() -> void:
	# Create overlay Control nodes for indicator lines
	# These will draw golden yellow vertical lines that move with current value

	min_indicator_overlay = Control.new()
	min_indicator_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(min_indicator_overlay)

	max_indicator_overlay = Control.new()
	max_indicator_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(max_indicator_overlay)

func _process_reaching() -> void:
	if step_reaching_complete:
		return

	var at_min = distance_current <= distance_min + NEAR_THRESHOLD
	var at_max = distance_current >= distance_max - NEAR_THRESHOLD

	if at_min and not last_reached_min:
		last_reached_min = true
		if last_reached_max:
			reach_count += 1
		last_reached_max = false
		flash_timer = 0.3
	elif at_max and not last_reached_max:
		last_reached_max = true
		last_reached_min = false
		flash_timer = 0.3

	_update_reaching_bars()

	if reach_count >= REQUIRED_REACHES:
		_complete_reaching()
	elif reaching_timer >= REACHING_TIME_LIMIT:
		_complete_reaching()

func _complete_reaching() -> void:
	step_reaching_complete = true
	current_step = AssessmentStep.COMPLETE

	if status_label:
		if reach_count >= REQUIRED_REACHES and reaching_timer <= REACHING_TIME_LIMIT:
			status_label.text = "✓ Reaching Complete! Reaches: %d in %.1f seconds - Click SAVE" % [reach_count, reaching_timer]
		else:
			status_label.text = "Time expired. Reaches: %d/%d - Click SAVE to submit" % [reach_count, REQUIRED_REACHES]

	if save_button:
		save_button.visible = true
	if reach_count_label:
		reach_count_label.visible = false

	# Clean up indicator overlays
	if min_indicator_overlay:
		min_indicator_overlay.queue_free()
		min_indicator_overlay = null
	if max_indicator_overlay:
		max_indicator_overlay.queue_free()
		max_indicator_overlay = null

	_update_display()
	print("TripodAssessment: Step 3 complete! Reaches: %d in %.2f seconds" % [reach_count, reaching_timer])

func _start_arom_raw_logging() -> void:
	AppDataTrial.start_arom_raw_data_logging()
	print("TripodAssessment: Started AROM raw data logging for Tripod Grip")

func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("TripodAssessment: Mechanism not initialized")
		if status_label:
			status_label.text = "Error: Mechanism not initialized. Cannot save."
		return

	# Stop AROM raw data logging
	AppDataTrial.stop_arom_raw_data_logging()

	# Set AROM values: min = minimum distance (compression), max = maximum distance (relaxed)
	Appdata.selected_mechanism.set_new_arom_values(distance_min, distance_max, float(int(reaching_timer)))

	# Save assessment data
	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! Distance: %.2f-%.2f cm | Reaches: %d/5 | Time: %d s" % [distance_min, distance_max, reach_count, int(reaching_timer)]
		print("TripodAssessment: Assessment saved successfully for Tripod Grip - Distance: %.2f-%.2f cm, Reaches: %d, Time: %d s" % [distance_min, distance_max, reach_count, int(reaching_timer)])
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scene/mechanism.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("TripodAssessment: Failed to save assessment data for Tripod Grip")

func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _cleanup() -> void:
	# Disconnect from signals to prevent errors when re-entering scene
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))

func _exit_tree() -> void:
	_cleanup()
