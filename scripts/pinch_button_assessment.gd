extends Node2D

var status_label: Label
var back_button: Button
var save_button: Button
var basic_assement_btn:Button
var validate_assessment_btn:Button
var progress_label: Label
var circleIndication : Sprite2D
var timertext : Label
var title : Label

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

const HOLD_TIME = 5.0  # Step 1 hold time
const HOLD_TIME_STEP2 = 3.0  # Step 2 hold time
const HOLDS_REQUIRED = 5
const TIME_LIMIT = 60.0


enum AssessmentPhase { SELECT,PINCH1, PINCH2, BUTTONS,COMPLETE}
var current_phase = AssessmentPhase.SELECT

func _ready() -> void:
	status_label = get_node_or_null("status_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	progress_label = get_node_or_null("progress_label")
	circleIndication = get_node_or_null("buttonstateUI")
	timertext = get_node_or_null("timertext")
	title = get_node_or_null("title2")
	basic_assement_btn = get_node_or_null("basic_assessment")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	# Make circle clickable to start assessments
	var circle_area = get_node_or_null("buttonstateUI/CircleClickArea")
	if circle_area:
		circle_area.input_event.connect(_on_circle_clicked)
		print("PinchButtonAssessment: Circle click area connected")
	else:
		print("PinchButtonAssessment: ERROR - Circle click area not found!")

	if HCcomm:
		HCcomm.new_device_data.connect(_on_device_data_received)
		print("PinchButtonAssessment: HCcomm connected")
	else:
		print("PinchButtonAssessment: WARNING - HCcomm not available")

	print("PinchButtonAssessment: Started, phase = %s" % AssessmentPhase.keys()[current_phase])
	_update_display()

func _process(delta: float) -> void:
	match current_phase:
		AssessmentPhase.PINCH1:
			_process_pinch1(delta)
		AssessmentPhase.PINCH2:
			_process_pinch2(delta)
		AssessmentPhase.BUTTONS:
			_process_buttons(delta)

func _input(event: InputEvent) -> void:
	# Fallback click detection for the circle area
	if event is InputEventMouseButton and event.pressed:
		var circle_pos = circleIndication.global_position if circleIndication else Vector2(958, 450)
		var click_pos = event.position
		var distance = click_pos.distance_to(circle_pos)
		if distance < 200:  # Rough circle radius in pixels after scaling
			print("PinchButtonAssessment: Circle clicked via _input fallback")
			_on_circle_clicked(null, event, click_pos)

func _on_device_data_received() -> void:
	match current_phase:
		AssessmentPhase.PINCH1:
			title.text = "PINCH-1"
			_handle_pinch1_data()
		AssessmentPhase.PINCH2:
			title.text = "PINCH-2"
			_handle_pinch2_data()
		AssessmentPhase.BUTTONS:
			title.text = "BUTTONS"
			_handle_button_data()

func _handle_pinch1_data() -> void:
	# Check button_6 for Pinch 1 (inverted: 0 = pressed, 1 = not pressed)
	pinch1_active = HCcomm.button_6 == 0
	pinch1_was_active = pinch1_active

	if circleIndication:
		circleIndication.modulate =  Color(1, 0, 0, 1) if pinch1_active else Color(0, 1, 0, 1)

func _handle_pinch2_data() -> void:
	# Check button_7 for Pinch 2 (inverted: 0 = pressed, 1 = not pressed)
	pinch2_active = HCcomm.button_7 == 0

	pinch2_was_active = pinch2_active

	if circleIndication:
		circleIndication.modulate = Color(1, 0, 0, 1) if pinch2_active else Color(0, 1, 0, 1)

func _handle_button_data() -> void:
	# Check if any button 1-5 is pressed (inverted: 0 = pressed, 1 = not pressed)
	var pressed = false
	if HCcomm.button_1 == 0 or HCcomm.button_2 == 0 or HCcomm.button_3 == 0 or HCcomm.button_4 == 0 or HCcomm.button_5 == 0:
		pressed = true

	buttons_active = pressed

	buttons_was_active = buttons_active

	if circleIndication:
		circleIndication.modulate = Color(1, 0, 0, 1) if buttons_active else Color(0, 1, 0, 1)

func _process_pinch1(delta: float) -> void:
	
	if current_step == 1:
		# Wait for first press, then start Step 1
		if not pinch1_first_press_happened:
			if pinch1_active:
				pinch1_first_press_happened = true
			if status_label:
				status_label.text = "PINCH 1 - STEP 1: Pull and hold the pinch..."
		else:
			# Step 1: Hold pinch for 5 seconds continuously (after first press detected)
			if pinch1_active:
				hold_timer += delta
				if status_label:
					if hold_timer < HOLD_TIME:
						if timertext and hold_timer <= HOLD_TIME:
							timertext.text = "%d" % max(1, int(hold_timer + 0.5))
						status_label.text = "PINCH 1 - STEP 1: Hold pinch (%.1f / 5.0 seconds)" % hold_timer
						status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
						# Circle visible while holding
						if circleIndication:
							circleIndication.modulate.a = 1.0
					else:
						status_label.text = "✓ Hold Complete! RELEASE the pinch to proceed to Step 2"
						status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
						# Circle disappears (opacity 0) when hold time reached
						if circleIndication:
							circleIndication.modulate.a = 0.0
							timertext.text = ""

				if hold_timer >= HOLD_TIME:
					pinch1_step1_complete = true
			else:
				if pinch1_step1_complete and hold_timer >= HOLD_TIME:
					# User released after holding for 5 seconds - restore circle visibility
					if circleIndication:
						circleIndication.modulate.a = 1.0
					if status_label:
						status_label.text = "✓ Step 1 Complete! Ready for Step 2 - Click the green circle to start Step 2"
						status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
					hold_timer = 0.0
				else:
					# Reset circle visibility if not completing
					if circleIndication:
						circleIndication.modulate.a = 1.0
					hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Hold pinch for 5 seconds, 5 times in 60 seconds
		timer += delta

		if pinch1_active:
			hold_timer += delta
			# Update visual timer display (stop at target time)
			if timertext and hold_timer <= HOLD_TIME_STEP2:
				timertext.text = "%d" % max(1, int(hold_timer + 0.5))
			if status_label:
				if hold_timer < HOLD_TIME_STEP2:
					status_label.text = "PINCH 1 - STEP 2: Hold %d of %d - Time: %.1f / 3.0 sec - Remaining: %.1f sec" % [hold_count + 1, HOLDS_REQUIRED, hold_timer, TIME_LIMIT - timer]
					status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
					# Circle visible while holding
					if circleIndication:
						circleIndication.modulate.a = 1.0
				else:
					status_label.text = "✓ PINCH 1 - Hold %d Complete! RELEASE to rest - Then press for Hold %d" % [hold_count , hold_count + 1]
					# Circle disappears when hold time reached
					if circleIndication:
						circleIndication.modulate.a = 0.0
						timertext.text = ""
					status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

			# Check if hold completed
			if hold_timer >= HOLD_TIME_STEP2 and not hold_completed_in_current_press:
				hold_count += 1
				hold_completed_in_current_press = true
				print("PinchButtonAssessment: PINCH1 Step 2 - Hold %d/%d completed" % [hold_count, HOLDS_REQUIRED])
		else:
			# Pinch released - restore circle visibility
			if circleIndication:
				circleIndication.modulate.a = 1.0
			if hold_completed_in_current_press and hold_timer >= HOLD_TIME:
				# Just released after a successful hold
				if status_label:
					if hold_count >= HOLDS_REQUIRED:
						status_label.text = "Released! All %d holds complete!" % HOLDS_REQUIRED
					else:
						status_label.text = "Released! %d / %d complete - Press again for hold %d" % [hold_count, HOLDS_REQUIRED, hold_count + 1]
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
				status_label.text = "PINCH 2 - STEP 1: Pull and hold the pinch..."
		else:
			# Step 1: Hold pinch for 5 seconds continuously (after first press detected)
			if pinch2_active:
				hold_timer += delta
				# Update visual timer display (stop at target time)
				if timertext and hold_timer <= HOLD_TIME:
					timertext.text = "%d" % max(1, int(hold_timer + 0.5))
				if status_label:
					if hold_timer < HOLD_TIME:
						status_label.text = "PINCH 2 - STEP 1: Hold pinch (%.1f / 5.0 seconds)" % hold_timer
						status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
						# Circle visible while holding
						if circleIndication:
							circleIndication.modulate.a = 1.0
					else:
						status_label.text = "✓ Hold Complete! RELEASE the pinch to proceed to Step 2"
						status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
						# Circle disappears when hold time reached
						if circleIndication:
							circleIndication.modulate.a = 0.0
							timertext.text = ""

				if hold_timer >= HOLD_TIME:
					pinch2_step1_complete = true
			else:
				if pinch2_step1_complete and hold_timer >= HOLD_TIME:
					# User released after holding for 5 seconds - restore circle visibility
					if circleIndication:
						circleIndication.modulate.a = 1.0
					if status_label:
						status_label.text = "✓ Step 1 Complete! Ready for Step 2 - Click the green circle to start Step 2"
						status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
					hold_timer = 0.0
				else:
					# Reset circle visibility if not completing
					if circleIndication:
						circleIndication.modulate.a = 1.0
					hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Hold pinch for 5 seconds, 5 times in 60 seconds
		timer += delta

		if pinch2_active:
			hold_timer += delta
			# Update visual timer display (stop at target time)
			if timertext and hold_timer <= HOLD_TIME_STEP2:
				timertext.text = "%d" % max(1, int(hold_timer + 0.5))
			if status_label:
				if hold_timer < HOLD_TIME_STEP2:
					status_label.text = "PINCH 2 - STEP 2: Hold %d of %d - Time: %.1f / 3.0 sec - Remaining: %.1f sec" % [hold_count + 1, HOLDS_REQUIRED, hold_timer, TIME_LIMIT - timer]
					status_label.add_theme_color_override("font_color", Color(0.8, 0, 0.9, 1))
					# Circle visible while holding
					if circleIndication:
						circleIndication.modulate.a = 1.0
				else:
					status_label.text = "✓ PINCH 2 - Hold %d Complete! RELEASE to rest - Then press for Hold %d" % [hold_count, hold_count + 1]
					# Circle disappears when hold time reached
					if circleIndication:
						circleIndication.modulate.a = 0.0
						timertext.text = ""
					status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

			# Check if hold completed
			if hold_timer >= HOLD_TIME_STEP2 and not hold_completed_in_current_press:
				hold_count += 1
				hold_completed_in_current_press = true
				print("PinchButtonAssessment: PINCH2 Step 2 - Hold %d/%d completed" % [hold_count, HOLDS_REQUIRED])
		else:
			# Pinch released - restore circle visibility
			if circleIndication:
				circleIndication.modulate.a = 1.0
			if hold_completed_in_current_press and hold_timer >= HOLD_TIME:
				# Just released after a successful hold
				if status_label:
					if hold_count >= HOLDS_REQUIRED:
						status_label.text = "Released! All %d holds complete!" % HOLDS_REQUIRED
					else:
						status_label.text = "Released! %d / %d complete - Press again for hold %d" % [hold_count, HOLDS_REQUIRED, hold_count + 1]
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
				# Update visual timer display (stop at target time)
				if timertext and hold_timer <= HOLD_TIME:
					timertext.text = "%d" % max(1, int(hold_timer + 0.5))
				if status_label:
					if hold_timer < HOLD_TIME:
						status_label.text = "BUTTONS - STEP 1: Hold button (%.1f / 5.0 seconds)" % hold_timer
						status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
						# Circle visible while holding
						if circleIndication:
							circleIndication.modulate.a = 1.0
					else:
						status_label.text = "✓ Hold Complete!,RELEASE the button to proceed to Step 2"
						status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
						# Circle disappears when hold time reached
						if circleIndication:
							circleIndication.modulate.a = 0.0
							timertext.text = ""

				if hold_timer >= HOLD_TIME:
					buttons_step1_complete = true
			else:
				if buttons_step1_complete and hold_timer >= HOLD_TIME:
					# User released after holding for 5 seconds - restore circle visibility
					if circleIndication:
						circleIndication.modulate.a = 1.0
					if status_label:
						status_label.text = "✓ Step 1 Complete! Ready for Step 2 - Click the green circle to start Step 2"
						status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
					hold_timer = 0.0
				else:
					# Reset circle visibility if not completing
					if circleIndication:
						circleIndication.modulate.a = 1.0
					hold_timer = 0.0

	elif current_step == 2:
		# Step 2: Hold button for 5 seconds, 5 times in 60 seconds
		timer += delta

		if buttons_active:
			hold_timer += delta
			# Update visual timer display (stop at target time)
			if timertext and hold_timer <= HOLD_TIME_STEP2:
				timertext.text = "%d" % max(1, int(hold_timer + 0.5))
			if status_label:
				if hold_timer < HOLD_TIME_STEP2:
					status_label.text = "BUTTONS - STEP 2: Hold %d of %d - Time: %.1f / 3.0 sec - Remaining: %.1f sec" % [hold_count + 1, HOLDS_REQUIRED, hold_timer, TIME_LIMIT - timer]
					status_label.add_theme_color_override("font_color", Color(1, 0.6, 0, 1))
					# Circle visible while holding
					if circleIndication:
						circleIndication.modulate.a = 1.0
				else:
					status_label.text = "✓ BUTTONS - Hold %d Complete! RELEASE to rest - Then press for Hold %d" % [hold_count , hold_count + 1]
					status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))
					# Circle disappears when hold time reached
					if circleIndication:
						circleIndication.modulate.a = 0.0
						timertext.text = ""

			# Check if hold completed
			if hold_timer >= HOLD_TIME_STEP2 and not hold_completed_in_current_press:
				hold_count += 1
				hold_completed_in_current_press = true
				print("PinchButtonAssessment: BUTTONS Step 2 - Hold %d/%d completed" % [hold_count, HOLDS_REQUIRED])
		else:
			# Button released - restore circle visibility
			if circleIndication:
				circleIndication.modulate.a = 1.0
			if hold_completed_in_current_press and hold_timer >= HOLD_TIME:
				# Just released after a successful hold
				if status_label:
					if hold_count >= HOLDS_REQUIRED:
						status_label.text = "Released! All %d holds complete!" % HOLDS_REQUIRED
					else:
						status_label.text = "Released! %d / %d complete - Press again for hold %d" % [hold_count, HOLDS_REQUIRED, hold_count + 1]
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
	print("PinchButtonAssessment: _update_display called, phase = %s" % AssessmentPhase.keys()[current_phase])
	if status_label:
		match current_phase:
			AssessmentPhase.SELECT:
				status_label.text = "Click the green circle to start PINCH 1 assessment"
				status_label.add_theme_color_override("font_color", Color(0, 0.9, 0.8, 1))
				if progress_label:
					progress_label.text = "Pinch 1: ○ | Pinch 2: ○ | Buttons: ○"
				return
			
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
					progress_label.text = "Pinch 1: %s | Pinch 2: %s | Buttons: %s" % [
						"✓" if pinch1_step2_complete else ("●" if pinch1_step1_complete else "○"),
						"✓" if pinch2_step2_complete else ("●" if pinch2_step1_complete else "○"),
						"✓" if buttons_step2_complete else ("●" if buttons_step1_complete else "○")]
					progress_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4, 1))

func _on_save_pressed() -> void:
	if Appdata.user_data.hospital_id == "":
		push_error("PinchButtonAssessment: Hospital ID not set")
		return

	# Read existing config
	var config_data = Datamanager.load_config(Appdata.user_data.hospital_id)

	# Update with new assessment flags
	var pinch1_complete = pinch1_step1_complete and pinch1_step2_complete
	var pinch2_complete = pinch2_step1_complete and pinch2_step2_complete
	var buttons_complete = buttons_step1_complete and buttons_step2_complete

	config_data["PinchGrasp1"] = pinch1_complete
	config_data["PinchGrasp2"] = pinch2_complete
	config_data["Buttons"] = buttons_complete

	# Save updated config
	if Datamanager.save_config(config_data):
		# Update user_data object with assessment completion status
		Appdata.user_data.pinch_grasp_1_done = pinch1_complete
		Appdata.user_data.pinch_grasp_2_done = pinch2_complete
		Appdata.user_data.buttons_done = buttons_complete

		if status_label:
			status_label.text = "✓ Assessment saved successfully!"
		print("PinchButtonAssessment: Assessment saved")
		print("  - Pinch Grasp 1: %s" % pinch1_complete)
		print("  - Pinch Grasp 2: %s" % pinch2_complete)
		print("  - Buttons: %s" % buttons_complete)
		print("🎮 Navigating to game launcher...")
		_cleanup()
		await get_tree().create_timer(1.5).timeout
		# Navigate to game launcher after AROM assessment complete
		get_tree().change_scene_to_file("res://scenes/safecrossing/sc_game.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment"
		push_error("PinchButtonAssessment: Failed to save assessment")

func _on_circle_clicked(_viewport: Node, event: InputEvent, _position: Vector2) -> void:
	print("PinchButtonAssessment: Circle clicked, event = %s" % event)
	if event is InputEventMouseButton and event.pressed:
		print("PinchButtonAssessment: Mouse button pressed, phase = %s" % AssessmentPhase.keys()[current_phase])
		match current_phase:
			AssessmentPhase.SELECT:
				# Start with Pinch 1
				current_phase = AssessmentPhase.PINCH1
				current_step = 1
				hold_timer = 0.0
				timer = 0.0
				hold_count = 0
				hold_completed_in_current_press = false
				pinch1_was_active = false
				_update_display()
				print("PinchButtonAssessment: Started Pinch 1 Assessment")
			AssessmentPhase.PINCH1:
				if current_step == 1 and pinch1_step1_complete:
					current_step = 2
					hold_timer = 0.0
					timer = 0.0
					hold_count = 0
					hold_completed_in_current_press = false
					_update_display()
					print("PinchButtonAssessment: Transitioned to Pinch 1 Step 2")
			AssessmentPhase.PINCH2:
				if current_step == 1 and pinch2_step1_complete:
					current_step = 2
					hold_timer = 0.0
					timer = 0.0
					hold_count = 0
					hold_completed_in_current_press = false
					_update_display()
					print("PinchButtonAssessment: Transitioned to Pinch 2 Step 2")
			AssessmentPhase.BUTTONS:
				if current_step == 1 and buttons_step1_complete:
					current_step = 2
					hold_timer = 0.0
					timer = 0.0
					hold_count = 0
					hold_completed_in_current_press = false
					_update_display()
					print("PinchButtonAssessment: Transitioned to Buttons Step 2")

func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _cleanup() -> void:
	# Disconnect from signals to prevent errors when re-entering scene
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))

func _exit_tree() -> void:
	_cleanup()
