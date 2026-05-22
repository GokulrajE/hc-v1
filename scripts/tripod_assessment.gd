extends Node2D

var status_label: Label
var distance_label: Label
var back_button: Button
var save_button: Button
var setmin_button: Button
var setmax_button: Button
var minprogressbar1: ProgressBar
var minprogressbar2: ProgressBar
var maxprogressbar1: ProgressBar
var maxprogressbar2: ProgressBar

var distance_current: float = 6.0
var distance_start: float = 6.0
var distance_min: float = 6.0
var distance_max: float = 6.0

# Tripod assessment states
enum AssessmentStep { setmax, setmin, complete }
var current_step = AssessmentStep.setmax

const MIN_DISTANCE = 2.0
const MAX_DISTANCE = 6.0

func _ready() -> void:
	status_label = get_node_or_null("status_label")
	distance_label = get_node_or_null("distance_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	setmin_button = get_node_or_null("setmin_button")
	setmax_button = get_node_or_null("setmax_button")
	minprogressbar1 = get_node_or_null("minProgressBarE-B")
	minprogressbar2 = get_node_or_null("minProgressBarE-B/minProgressBarB-E")
	maxprogressbar1 = get_node_or_null("maxProgressBarE-B2")
	maxprogressbar2 = get_node_or_null("maxProgressBarE-B2/maxProgressBarB-E")

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

	if HCcomm:
		# Disconnect if already connected to prevent duplicate signal error
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)

	print("TripodAssessment: Started for Tripod Grip mechanism")
	_start_arom_raw_logging()
	_update_display()

func _process(_delta: float) -> void:
	pass

func _on_device_data_received() -> void:
	distance_current = HCcomm.get_btw_distance()

	match current_step:
		AssessmentStep.setmax:
			_update_max_bars()
		AssessmentStep.setmin:
			_update_min_bars()

	if distance_label:
		distance_label.text = "Distance: %.2f cm" % distance_current

func _update_min_bars() -> void:
	# Track minimum distance during compression phase
	if distance_current < distance_min:
		distance_min = distance_current

	# Update min progress bars
	if minprogressbar1:
		minprogressbar1.value = distance_current
	if minprogressbar2:
		minprogressbar2.value = distance_current

func _update_max_bars() -> void:
	# Track maximum distance during recovery phase
	if distance_current > distance_max:
		distance_max = distance_current

	# Update max progress bars
	if maxprogressbar1:
		maxprogressbar1.value = distance_current
	if maxprogressbar2:
		maxprogressbar2.value = distance_current

func _update_display() -> void:
	if status_label:
		match current_step:
			AssessmentStep.setmax:
				status_label.text = "STEP 1: Release and expand to find maximum extension distance, then click SET MAX"
			AssessmentStep.setmin:
				status_label.text = "STEP 2: Squeeze the tripod grip to find minimum compression distance, then click SET MIN"
			AssessmentStep.complete:
				status_label.text = "✓ Assessment complete! Click SAVE ASSESSMENT to store results"

func _on_setmax_pressed() -> void:
	# Store the maximum value and move to setmin phase
	distance_max = distance_current
	current_step = AssessmentStep.setmin
	setmax_button.visible = false
	setmin_button.visible = true
	_update_display()
	print("TripodAssessment: Maximum distance set to %.2f cm - Now finding minimum" % distance_max)

func _on_setmin_pressed() -> void:
	# Store the minimum value and show save button
	distance_min = distance_current
	current_step = AssessmentStep.complete
	setmin_button.visible = false
	save_button.visible = true
	_update_display()
	print("TripodAssessment: Minimum distance set to %.2f cm - Ready to save" % distance_min)

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
	Appdata.selected_mechanism.set_new_arom_values(distance_min, distance_max, 0.0)

	# Save assessment data
	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! Distance Range: %.2f - %.2f cm" % [distance_min, distance_max]
		print("TripodAssessment: Assessment saved successfully for Tripod Grip")
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
