extends Node2D

var status_label: Label
var back_button: Button
var save_button: Button

# Sprite references
var pinch1_sprite: ColorRect
var pinch2_sprite: ColorRect
var buttons_sprite: ColorRect

# Assessment items
var pinch1_step1_complete: bool = false
var pinch1_step2_complete: bool = false
var pinch2_step1_complete: bool = false
var pinch2_step2_complete: bool = false
var buttons_step1_complete: bool = false
var buttons_step2_complete: bool = false

# State tracking for continuous detection
var pinch1_active: bool = false
var pinch2_active: bool = false
var buttons_active: bool = false
var pinch1_was_active: bool = false
var pinch2_was_active: bool = false
var buttons_was_active: bool = false

# Track if first press happened (to start step 1 from first press)
var pinch1_first_press_happened: bool = false
var pinch2_first_press_happened: bool = false
var buttons_first_press_happened: bool = false

# Current assessment tracking
var current_step: int = 1
var hold_timer: float = 0.0
var state_transitions: int = 0  # Count how many times state changed from inactive to active
var timer: float = 0.0

const HOLD_TIME = 5.0
const TRANSITIONS_REQUIRED = 5
const TIME_LIMIT = 60.0

enum AssessmentPhase { SELECT, PINCH1, PINCH2, BUTTONS, COMPLETE }
var current_phase = AssessmentPhase.SELECT

func _ready() -> void:
	status_label = get_node_or_null("status_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	pinch1_sprite = get_node_or_null("pinch1_sprite")
	pinch2_sprite = get_node_or_null("pinch2_sprite")
	buttons_sprite = get_node_or_null("buttons_sprite")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	# Make sprites clickable to start assessments
	if pinch1_sprite:
		pinch1_sprite.gui_input.connect(_on_pinch1_sprite_clicked)
	if pinch2_sprite:
		pinch2_sprite.gui_input.connect(_on_pinch2_sprite_clicked)
	if buttons_sprite:
		buttons_sprite.gui_input.connect(_on_buttons_sprite_clicked)

	if HCcomm:
		HCcomm.new_device_data.connect(_on_device_data_received)

	print("PinchButtonAssessment: Started")
	_update_display()

func _process(delta: float) -> void:
	match current_phase:
		AssessmentPhase.PINCH1:
			_process_pinch1(delta)
		AssessmentPhase.PINCH2:
			_process_pinch2(delta)
		AssessmentPhase.BUTTONS:
			_process_buttons(delta)

func _on_device_data_received() -> void:
	match current_phase:
		AssessmentPhase.PINCH1:
			_handle_pinch1_data()
		AssessmentPhase.PINCH2:
			_handle_pinch2_data()
		AssessmentPhase.BUTTONS:
			_handle_button_data()

func _handle_pinch1_data() -> void:
	# Check button_6 for Pinch 1 (inverted: 0 = pressed, 1 = not pressed)
	pinch1_active = HCcomm.button_6 == 0

	# Detect state transition from inactive to active (0 -> 1 becomes false -> true)
	if pinch1_active and not pinch1_was_active:
		state_transitions += 1

	pinch1_was_active = pinch1_active

	# Update sprite color based on pinch state
	if pinch1_sprite:
		pinch1_sprite.modulate = Color.GREEN if pinch1_active else Color.WHITE

func _handle_pinch2_data() -> void:
	# Check button_7 for Pinch 2 (inverted: 0 = pressed, 1 = not pressed)
	pinch2_active = HCcomm.button_7 == 0

	if pinch2_active and not pinch2_was_active:
		state_transitions += 1

	pinch2_was_active = pinch2_active

	if pinch2_sprite:
		pinch2_sprite.modulate = Color.GREEN if pinch2_active else Color.WHITE

func _handle_button_data() -> void:
	# Check if any button 1-5 is pressed (inverted: 0 = pressed, 1 = not pressed)
	var pressed = false
	if HCcomm.button_1 == 0 or HCcomm.button_2 == 0 or HCcomm.button_3 == 0 or HCcomm.button_4 == 0 or HCcomm.button_5 == 0:
		pressed = true

	buttons_active = pressed

	if buttons_active and not buttons_was_active:
		state_transitions += 1

	buttons_was_active = buttons_active

	if buttons_sprite:
		buttons_sprite.modulate = Color.GREEN if buttons_active else Color.WHITE

func _process_pinch1(delta: float) -> void:
	if current_step == 1:
		# Wait for first press, then start Step 1
		if not pinch1_first_press_happened:
			if pinch1_active:
				pinch1_first_press_happened = true
			if status_label:
				status_label.text = "PINCH 1 - STEP 1: Press and hold the pinch..."
		else:
			# Step 1: Hold pinch for 5 seconds continuously (after first press detected)
			if pinch1_active:
				hold_timer += delta
				if status_label:
					status_label.text = "PINCH 1 - STEP 1: Hold pinch (%.1f/5.0 sec)" % hold_timer

				if hold_timer >= HOLD_TIME:
					pinch1_step1_complete = true
					current_step = 2
					hold_timer = 0.0
					timer = 0.0
					state_transitions = 0
					pinch1_first_press_happened = false
					_update_display()
			else:
				hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Start/stop pinch 5 times in 1 minute
		timer += delta
		if status_label:
			status_label.text = "PINCH 1 - STEP 2: Release and pinch %d/%d times (%.1f/60.0 sec)" % [state_transitions, TRANSITIONS_REQUIRED, timer]

		if state_transitions >= TRANSITIONS_REQUIRED:
			pinch1_step2_complete = true
			current_phase = AssessmentPhase.PINCH2
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			state_transitions = 0
			pinch1_was_active = false
			pinch2_was_active = false
			_update_display()
		elif timer >= TIME_LIMIT:
			current_phase = AssessmentPhase.PINCH2
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			state_transitions = 0
			pinch2_was_active = false
			_update_display()

func _process_pinch2(delta: float) -> void:
	if current_step == 1:
		# Wait for first press, then start Step 1
		if not pinch2_first_press_happened:
			if pinch2_active:
				pinch2_first_press_happened = true
			if status_label:
				status_label.text = "PINCH 2 - STEP 1: Press and hold the pinch..."
		else:
			# Step 1: Hold pinch for 5 seconds continuously (after first press detected)
			if pinch2_active:
				hold_timer += delta
				if status_label:
					status_label.text = "PINCH 2 - STEP 1: Hold pinch (%.1f/5.0 sec)" % hold_timer

				if hold_timer >= HOLD_TIME:
					pinch2_step1_complete = true
					current_step = 2
					hold_timer = 0.0
					timer = 0.0
					state_transitions = 0
					pinch2_first_press_happened = false
					_update_display()
			else:
				hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Start/stop pinch 5 times in 1 minute
		timer += delta
		if status_label:
			status_label.text = "PINCH 2 - STEP 2: Release and pinch %d/%d times (%.1f/60.0 sec)" % [state_transitions, TRANSITIONS_REQUIRED, timer]

		if state_transitions >= TRANSITIONS_REQUIRED:
			pinch2_step2_complete = true
			current_phase = AssessmentPhase.BUTTONS
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			state_transitions = 0
			pinch2_was_active = false
			buttons_was_active = false
			_update_display()
		elif timer >= TIME_LIMIT:
			current_phase = AssessmentPhase.BUTTONS
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			state_transitions = 0
			buttons_was_active = false
			_update_display()

func _process_buttons(delta: float) -> void:
	if current_step == 1:
		# Wait for first press, then start Step 1
		if not buttons_first_press_happened:
			if buttons_active:
				buttons_first_press_happened = true
			if status_label:
				status_label.text = "BUTTONS - STEP 1: Press and hold a button..."
		else:
			# Step 1: Hold button for 5 seconds continuously (after first press detected)
			if buttons_active:
				hold_timer += delta
				if status_label:
					status_label.text = "BUTTONS - STEP 1: Hold button (%.1f/5.0 sec)" % hold_timer

				if hold_timer >= HOLD_TIME:
					buttons_step1_complete = true
					current_step = 2
					hold_timer = 0.0
					timer = 0.0
					state_transitions = 0
					buttons_first_press_happened = false
					_update_display()
			else:
				hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Press/release button 5 times in 1 minute
		timer += delta
		if status_label:
			status_label.text = "BUTTONS - STEP 2: Release and press %d/%d times (%.1f/60.0 sec)" % [state_transitions, TRANSITIONS_REQUIRED, timer]

		if state_transitions >= TRANSITIONS_REQUIRED:
			buttons_step2_complete = true
			current_phase = AssessmentPhase.COMPLETE
			if save_button:
				save_button.visible = true
			_update_display()
		elif timer >= TIME_LIMIT:
			current_phase = AssessmentPhase.COMPLETE
			if save_button:
				save_button.visible = true
			_update_display()

func _update_display() -> void:
	if status_label:
		match current_phase:
			AssessmentPhase.SELECT:
				status_label.text = "Select assessment to begin"
			AssessmentPhase.PINCH1:
				status_label.text = "PINCH 1 Assessment - STEP %d" % current_step
			AssessmentPhase.PINCH2:
				status_label.text = "PINCH 2 Assessment - STEP %d" % current_step
			AssessmentPhase.BUTTONS:
				status_label.text = "BUTTONS Assessment - STEP %d" % current_step
			AssessmentPhase.COMPLETE:
				status_label.text = "✓ All assessments complete! Click SAVE to store results"

func _on_save_pressed() -> void:
	if Appdata.hospital_id == "":
		push_error("PinchButtonAssessment: Hospital ID not set")
		return

	# Read existing config
	var config_data = DataManager.load_config(Appdata.hospital_id)

	# Update with new assessment flags
	config_data["PinchGrasp1"] = pinch1_step1_complete and pinch1_step2_complete
	config_data["PinchGrasp2"] = pinch2_step1_complete and pinch2_step2_complete
	config_data["Buttons"] = buttons_step1_complete and buttons_step2_complete


	# Save updated config
	if DataManager.save_config(config_data):
		if status_label:
			status_label.text = "✓ Assessment saved successfully!"
		print("PinchButtonAssessment: Assessment saved")
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scene/mechanism.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment"
		push_error("PinchButtonAssessment: Failed to save assessment")

func _on_pinch1_sprite_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and current_phase == AssessmentPhase.SELECT:
		current_phase = AssessmentPhase.PINCH1
		current_step = 1
		hold_timer = 0.0
		timer = 0.0
		state_transitions = 0
		pinch1_was_active = false
		_update_display()
		print("PinchButtonAssessment: Started Pinch 1 Assessment")

func _on_pinch2_sprite_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and current_phase == AssessmentPhase.SELECT:
		current_phase = AssessmentPhase.PINCH2
		current_step = 1
		hold_timer = 0.0
		timer = 0.0
		state_transitions = 0
		pinch2_was_active = false
		_update_display()
		print("PinchButtonAssessment: Started Pinch 2 Assessment")

func _on_buttons_sprite_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and current_phase == AssessmentPhase.SELECT:
		current_phase = AssessmentPhase.BUTTONS
		current_step = 1
		hold_timer = 0.0
		timer = 0.0
		state_transitions = 0
		buttons_was_active = false
		_update_display()
		print("PinchButtonAssessment: Started Buttons Assessment")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")
