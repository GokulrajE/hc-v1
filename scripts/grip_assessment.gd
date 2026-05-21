extends Node2D

var grip_progress: ProgressBar
var grip_value: Label
var back_button: Button
var save_button: Button
var status_label: Label

var grip_value_current: float = 0.0
var grip_max: float = 0.0
var current_mechanism = null

func _ready() -> void:
	grip_progress = get_node_or_null("grip_progress")
	grip_value = get_node_or_null("grip_value")
	back_button = get_node_or_null("back_button")
	status_label = get_node_or_null("status_label")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Create save button if it doesn't exist
	if not has_node("save_button"):
		save_button = Button.new()
		save_button.name = "save_button"
		add_child(save_button)
		save_button.position = Vector2(1650, 950)
		save_button.size = Vector2(200, 70)
		save_button.text = "Save Assessment"
		save_button.add_theme_font_size_override("font_size", 30)
	else:
		save_button = get_node_or_null("save_button")

	if save_button:
		save_button.pressed.connect(_on_save_pressed)

	if HCcomm:
		HCcomm.new_device_data.connect(_on_device_data_received)

	print("GripAssessment: Started for Grip Force Assessment")
	_start_arom_raw_logging()
	_update_display()

func _get_current_grip_value() -> float:
	return HCcomm.get_total_force()

func _on_device_data_received() -> void:
	grip_value_current = _get_current_grip_value()

	# Track maximum grip force
	if grip_value_current > grip_max:
		grip_max = grip_value_current

	if grip_value:
		grip_value.text = "Grip: %.1f N" % grip_value_current

	_update_progress()

func _update_display() -> void:
	if status_label:
		status_label.text = "GRIP ASSESSMENT: Squeeze handle with maximum force - Click SAVE when done"

func _update_progress() -> void:
	if grip_progress:
		grip_progress.value = float(grip_value_current)

func _start_arom_raw_logging() -> void:
	AppDataTrial.start_arom_raw_data_logging()
	print("GripAssessment: Started AROM raw data logging for Grip Force")

func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("GripAssessment: Mechanism not initialized")
		if status_label:
			status_label.text = "Error: Mechanism not initialized. Cannot save."
		return

	# Stop AROM raw data logging
	AppDataTrial.stop_arom_raw_data_logging()

	# Set AROM values: min = 0.0 (always), max = grip_max force
	Appdata.selected_mechanism.set_new_arom_values(0.0, grip_max)

	# Save assessment data
	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! Grip Force: 0.0 N to %.1f N" % grip_max
		print("GripAssessment: Assessment saved successfully for Grip Force")
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scene/mechanism.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("GripAssessment: Failed to save assessment data for Grip Force")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")
