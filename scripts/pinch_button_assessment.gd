extends Node2D

var status_label: Label
var back_button: Button
var save_button: Button
var progress_label: Label

# Card references
var pinch1_card: ColorRect
var pinch2_card: ColorRect
var buttons_card: ColorRect

# Status label references
var pinch1_status: Label
var pinch2_status: Label
var buttons_status: Label

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
var hold_count: int = 0  # Count how many 5-second holds completed
var hold_completed_in_current_press: bool = false  # Track if current press already counted
var timer: float = 0.0

const HOLD_TIME = 5.0
const HOLDS_REQUIRED = 5
const TIME_LIMIT = 60.0

enum AssessmentPhase { SELECT, PINCH1, PINCH2, BUTTONS, COMPLETE }
var current_phase = AssessmentPhase.SELECT

func _ready() -> void:
	status_label = get_node_or_null("status_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	progress_label = get_node_or_null("progress_label")

	pinch1_card = get_node_or_null("assessment_container/pinch1_card")
	pinch2_card = get_node_or_null("assessment_container/pinch2_card")
	buttons_card = get_node_or_null("assessment_container/buttons_card")

	pinch1_status = get_node_or_null("assessment_container/pinch1_card/pinch1_status")
	pinch2_status = get_node_or_null("assessment_container/pinch2_card/pinch2_status")
	buttons_status = get_node_or_null("assessment_container/buttons_card/buttons_status")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	# Make cards clickable to start assessments
	if pinch1_card:
		pinch1_card.gui_input.connect(_on_pinch1_sprite_clicked)
	if pinch2_card:
		pinch2_card.gui_input.connect(_on_pinch2_sprite_clicked)
	if buttons_card:
		buttons_card.gui_input.connect(_on_buttons_sprite_clicked)

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

	pinch1_was_active = pinch1_active

	# Update card color based on pinch state
	if pinch1_card:
		pinch1_card.color = Color(0.3, 0.6, 0.5, 1) if pinch1_active else Color(0.2, 0.2, 0.25, 1)

func _handle_pinch2_data() -> void:
	# Check button_7 for Pinch 2 (inverted: 0 = pressed, 1 = not pressed)
	pinch2_active = HCcomm.button_7 == 0

	pinch2_was_active = pinch2_active

	if pinch2_card:
		pinch2_card.color = Color(0.6, 0.3, 0.8, 1) if pinch2_active else Color(0.2, 0.2, 0.25, 1)

func _handle_button_data() -> void:
	# Check if any button 1-5 is pressed (inverted: 0 = pressed, 1 = not pressed)
	var pressed = false
	if HCcomm.button_1 == 0 or HCcomm.button_2 == 0 or HCcomm.button_3 == 0 or HCcomm.button_4 == 0 or HCcomm.button_5 == 0:
		pressed = true

	buttons_active = pressed

	buttons_was_active = buttons_active

	if buttons_card:
		buttons_card.color = Color(1, 0.7, 0.2, 1) if buttons_active else Color(0.2, 0.2, 0.25, 1)

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
					if hold_timer < HOLD_TIME:
						status_label.text = "PINCH 1 - STEP 1: Hold pinch (%.1f / 5.0 seconds)" % hold_timer
						status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
					else:
						status_label.text = "✓ Hold Complete! RELEASE the pinch to proceed to Step 2"
						status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

				if hold_timer >= HOLD_TIME:
					pinch1_step1_complete = true
			else:
				if pinch1_step1_complete and hold_timer >= HOLD_TIME:
					# User released after holding for 5 seconds
					if status_label:
						status_label.text = "✓ Step 1 Complete! Ready for Step 2 - Click PINCH 1 card to start Step 2"
						status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
					hold_timer = 0.0
				else:
					hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Hold pinch for 5 seconds, 5 times in 60 seconds
		timer += delta

		if pinch1_active:
			hold_timer += delta
			if status_label:
				if hold_timer < HOLD_TIME:
					status_label.text = "PINCH 1 - STEP 2: Hold #%d of %d | (%.1f / 5.0 sec) | Time: %.1f / 60.0 sec" % [hold_count + 1, HOLDS_REQUIRED, hold_timer, TIME_LIMIT - timer]
				else:
					status_label.text = "✓ Hold %d Complete! RELEASE to rest - Then press for Hold %d" % [hold_count + 1, hold_count + 2]

			# Check if hold completed
			if hold_timer >= HOLD_TIME and not hold_completed_in_current_press:
				hold_count += 1
				hold_completed_in_current_press = true
				print("PinchButtonAssessment: PINCH1 Step 2 - Hold %d/%d completed" % [hold_count, HOLDS_REQUIRED])
		else:
			# Pinch released
			if hold_completed_in_current_press and hold_timer >= HOLD_TIME:
				# Just released after a successful hold
				if status_label:
					if hold_count < HOLDS_REQUIRED:
						status_label.text = "Released! %d / %d complete - Press again for the next hold" % [hold_count, HOLDS_REQUIRED]
						status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
			hold_timer = 0.0
			hold_completed_in_current_press = false

		if hold_count >= HOLDS_REQUIRED:
			pinch1_step2_complete = true
			current_phase = AssessmentPhase.PINCH2
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			pinch1_was_active = false
			pinch2_was_active = false
			_update_display()
		elif timer >= TIME_LIMIT:
			current_phase = AssessmentPhase.PINCH2
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
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
					if hold_timer < HOLD_TIME:
						status_label.text = "PINCH 2 - STEP 1: Hold pinch (%.1f / 5.0 seconds)" % hold_timer
						status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
					else:
						status_label.text = "✓ Hold Complete! RELEASE the pinch to proceed to Step 2"
						status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

				if hold_timer >= HOLD_TIME:
					pinch2_step1_complete = true
			else:
				if pinch2_step1_complete and hold_timer >= HOLD_TIME:
					# User released after holding for 5 seconds
					if status_label:
						status_label.text = "✓ Step 1 Complete! Ready for Step 2 - Click PINCH 2 card to start Step 2"
						status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
					hold_timer = 0.0
				else:
					hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Hold pinch for 5 seconds, 5 times in 60 seconds
		timer += delta

		if pinch2_active:
			hold_timer += delta
			if status_label:
				if hold_timer < HOLD_TIME:
					status_label.text = "PINCH 2 - STEP 2: Hold #%d of %d | (%.1f / 5.0 sec) | Time: %.1f / 60.0 sec" % [hold_count + 1, HOLDS_REQUIRED, hold_timer, TIME_LIMIT - timer]
				else:
					status_label.text = "✓ Hold %d Complete! RELEASE to rest - Then press for Hold %d" % [hold_count + 1, hold_count + 2]

			# Check if hold completed
			if hold_timer >= HOLD_TIME and not hold_completed_in_current_press:
				hold_count += 1
				hold_completed_in_current_press = true
				print("PinchButtonAssessment: PINCH2 Step 2 - Hold %d/%d completed" % [hold_count, HOLDS_REQUIRED])
		else:
			# Pinch released
			if hold_completed_in_current_press and hold_timer >= HOLD_TIME:
				# Just released after a successful hold
				if status_label:
					if hold_count < HOLDS_REQUIRED:
						status_label.text = "Released!%d / %d complete, Press again for the next hold" % [hold_count, HOLDS_REQUIRED]
						status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
			hold_timer = 0.0
			hold_completed_in_current_press = false

		if hold_count >= HOLDS_REQUIRED:
			pinch2_step2_complete = true
			current_phase = AssessmentPhase.BUTTONS
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			pinch2_was_active = false
			buttons_was_active = false
			_update_display()
		elif timer >= TIME_LIMIT:
			current_phase = AssessmentPhase.BUTTONS
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
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
					if hold_timer < HOLD_TIME:
						status_label.text = "BUTTONS - STEP 1: Hold button (%.1f / 5.0 seconds)" % hold_timer
						status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
					else:
						status_label.text = "✓ Hold Complete!,RELEASE the button to proceed to Step 2"
						status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

				if hold_timer >= HOLD_TIME:
					buttons_step1_complete = true
			else:
				if buttons_step1_complete and hold_timer >= HOLD_TIME:
					# User released after holding for 5 seconds
					if status_label:
						status_label.text = "✓ Step 1 Complete! Ready for Step 2 - Click BUTTONS card to start Step 2"
						status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
					hold_timer = 0.0
				else:
					hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Hold button for 5 seconds, 5 times in 60 seconds
		timer += delta

		if buttons_active:
			hold_timer += delta
			if status_label:
				if hold_timer < HOLD_TIME:
					status_label.text = "BUTTONS - STEP 2: Hold #%d of %d | (%.1f / 5.0 sec) | Time: %.1f / 60.0 sec" % [hold_count + 1, HOLDS_REQUIRED, hold_timer, TIME_LIMIT - timer]
				else:
					status_label.text = "✓ Hold %d Complete! RELEASE to rest - Then press for Hold %d" % [hold_count + 1, hold_count + 2]

			# Check if hold completed
			if hold_timer >= HOLD_TIME and not hold_completed_in_current_press:
				hold_count += 1
				hold_completed_in_current_press = true
				print("PinchButtonAssessment: BUTTONS Step 2 - Hold %d/%d completed" % [hold_count, HOLDS_REQUIRED])
		else:
			# Button released
			if hold_completed_in_current_press and hold_timer >= HOLD_TIME:
				# Just released after a successful hold
				if status_label:
					if hold_count < HOLDS_REQUIRED:
						status_label.text = "Released! %d / %d complete - Press again for the next hold" % [hold_count, HOLDS_REQUIRED]
						status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
			hold_timer = 0.0
			hold_completed_in_current_press = false

		if hold_count >= HOLDS_REQUIRED:
			buttons_step2_complete = true
			current_phase = AssessmentPhase.COMPLETE
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			if save_button:
				save_button.visible = true
			_update_display()
		elif timer >= TIME_LIMIT:
			current_phase = AssessmentPhase.COMPLETE
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			if save_button:
				save_button.visible = true
			_update_display()

func _update_display() -> void:
	# Update assessment status cards
	if pinch1_status:
		if pinch1_step1_complete and pinch1_step2_complete:
			pinch1_status.text = "✓ COMPLETE"
			pinch1_status.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
		elif pinch1_step1_complete:
			pinch1_status.text = "Step 2 in progress..."
			pinch1_status.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
		else:
			pinch1_status.text = "Click to start"
			pinch1_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

	if pinch2_status:
		if pinch2_step1_complete and pinch2_step2_complete:
			pinch2_status.text = "✓ COMPLETE"
			pinch2_status.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
		elif pinch2_step1_complete:
			pinch2_status.text = "Step 2 in progress..."
			pinch2_status.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
		else:
			pinch2_status.text = "Click to start"
			pinch2_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

	if buttons_status:
		if buttons_step1_complete and buttons_step2_complete:
			buttons_status.text = "✓ COMPLETE"
			buttons_status.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
		elif buttons_step1_complete:
			buttons_status.text = "Step 2 in progress..."
			buttons_status.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
		else:
			buttons_status.text = "Click to start"
			buttons_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

	if status_label:
		match current_phase:
			AssessmentPhase.SELECT:
				status_label.text = "Select an assessment to begin"
				status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
				if progress_label:
					progress_label.text = ""
			AssessmentPhase.PINCH1:
				status_label.text = "PINCH 1 Assessment - STEP %d (Press and hold for 5 seconds)" % current_step
				status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
				if progress_label:
					progress_label.text = "Pinch 1: %s | Pinch 2: %s | Buttons: %s" % [
						"✓" if pinch1_step2_complete else ("●" if pinch1_step1_complete else "○"),
						"✓" if pinch2_step2_complete else ("●" if pinch2_step1_complete else "○"),
						"✓" if buttons_step2_complete else ("●" if buttons_step1_complete else "○")
					]
			AssessmentPhase.PINCH2:
				status_label.text = "PINCH 2 Assessment - STEP %d (Press and hold for 5 seconds)" % current_step
				status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
				if progress_label:
					progress_label.text = "Pinch 1: %s | Pinch 2: %s | Buttons: %s" % [
						"✓" if pinch1_step2_complete else ("●" if pinch1_step1_complete else "○"),
						"✓" if pinch2_step2_complete else ("●" if pinch2_step1_complete else "○"),
						"✓" if buttons_step2_complete else ("●" if buttons_step1_complete else "○")
					]
			AssessmentPhase.BUTTONS:
				status_label.text = "BUTTONS Assessment - STEP %d (Press and hold for 5 seconds)" % current_step
				status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
				if progress_label:
					progress_label.text = "Pinch 1: %s | Pinch 2: %s | Buttons: %s" % [
						"✓" if pinch1_step2_complete else ("●" if pinch1_step1_complete else "○"),
						"✓" if pinch2_step2_complete else ("●" if pinch2_step1_complete else "○"),
						"✓" if buttons_step2_complete else ("●" if buttons_step1_complete else "○")
					]
			AssessmentPhase.COMPLETE:
				status_label.text = "✓ All assessments complete! Click SAVE to store results"
				status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
				if progress_label:
					progress_label.text = "Pinch 1: ✓ | Pinch 2: ✓ | Buttons: ✓"
					progress_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

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
	if event is InputEventMouseButton and event.pressed:
		if current_phase == AssessmentPhase.SELECT:
			current_phase = AssessmentPhase.PINCH1
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			pinch1_was_active = false
			_update_display()
			print("PinchButtonAssessment: Started Pinch 1 Assessment")
		elif current_phase == AssessmentPhase.PINCH1 and current_step == 1 and pinch1_step1_complete:
			# Transition from Step 1 to Step 2
			current_step = 2
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			_update_display()
			print("PinchButtonAssessment: Transitioned to Pinch 1 Step 2")

func _on_pinch2_sprite_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if current_phase == AssessmentPhase.SELECT:
			current_phase = AssessmentPhase.PINCH2
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			pinch2_was_active = false
			_update_display()
			print("PinchButtonAssessment: Started Pinch 2 Assessment")
		elif current_phase == AssessmentPhase.PINCH2 and current_step == 1 and pinch2_step1_complete:
			# Transition from Step 1 to Step 2
			current_step = 2
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			_update_display()
			print("PinchButtonAssessment: Transitioned to Pinch 2 Step 2")

func _on_buttons_sprite_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if current_phase == AssessmentPhase.SELECT:
			current_phase = AssessmentPhase.BUTTONS
			current_step = 1
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			buttons_was_active = false
			_update_display()
			print("PinchButtonAssessment: Started Buttons Assessment")
		elif current_phase == AssessmentPhase.BUTTONS and current_step == 1 and buttons_step1_complete:
			# Transition from Step 1 to Step 2
			current_step = 2
			hold_timer = 0.0
			timer = 0.0
			hold_count = 0
			hold_completed_in_current_press = false
			_update_display()
			print("PinchButtonAssessment: Transitioned to Buttons Step 2")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")
