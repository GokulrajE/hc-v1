extends Node2D

var hand_grip_button: Button
var grip_button: Button
var knob: Button
var fine_knob: Button
var key_knob: Button
var tripod_grip_button: Button
var pinch_button_button: Button
var back_button: Button
var message_label: Label

func _ready() -> void:
	hand_grip_button = get_node_or_null("hand_grip_button")
	grip_button = get_node_or_null("grip_button")
	knob = get_node_or_null("knob")
	fine_knob = get_node_or_null("fine_knob")
	key_knob = get_node_or_null("key_knob")
	tripod_grip_button = get_node_or_null("tripod_grip_button")
	pinch_button_button = get_node_or_null("pinch_button_button")
	back_button = get_node_or_null("back_button")
	message_label = get_node_or_null("message_label")

	if hand_grip_button:
		hand_grip_button.text = "Handle"
		hand_grip_button.pressed.connect(_on_hand_grip_pressed)

	if grip_button:
		grip_button.pressed.connect(_on_grip_pressed)

	if knob:
		knob.pressed.connect(_on_knob_selected)

	if fine_knob:
		fine_knob.pressed.connect(_on_fine_knob_selected)

	if key_knob:
		key_knob.pressed.connect(_on_key_knob_selected)

	if tripod_grip_button:
		tripod_grip_button.pressed.connect(_on_tripod_grip_pressed)

	if pinch_button_button:
		pinch_button_button.pressed.connect(_on_pinch_button_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_hand_grip_pressed() -> void:
	Appdata.set_mechanism("Handle")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ AROM already completed for HANDLE\n(Min: %.2f° | Max: %.2f°)\nSelect another mechanism or go back." % [
			Appdata.selected_mechanism.old_rom.arom_min,
			Appdata.selected_mechanism.old_rom.arom_max
		]
	else:
		message_label.text = "Starting AROM assessment for Handle...\nPlease squeeze the handle through its full range."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/handle_assessment.tscn")

func _on_grip_pressed() -> void:
	Appdata.set_mechanism("Grip")

	# Check if grip force assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ Grip assessment already completed\n(Max Force: %.1f N)\nSelect another mechanism or go back." % [
			Appdata.selected_mechanism.old_rom.arom_max
		]
	else:
		message_label.text = "Starting Grip Force assessment...\nPlease squeeze the handle with maximum force."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/grip_assessment.tscn")

func _on_knob_selected() -> void:
	Appdata.set_mechanism("Knob")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ AROM already completed for KNOB\n(Min: %.2f° | Max: %.2f°)\nSelect another mechanism or go back." % [
			Appdata.selected_mechanism.old_rom.arom_min,
			Appdata.selected_mechanism.old_rom.arom_max
		]
	else:
		message_label.text = "Starting AROM assessment for Knob...\nPlease rotate the knob through its full range."
		await get_tree().create_timer(0.5).timeout  # Small delay before scene change
		get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_fine_knob_selected() -> void:
	Appdata.set_mechanism("Fine Knob")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ AROM already completed for FINE KNOB\n(Min: %.2f° | Max: %.2f°)\nSelect another mechanism or go back." % [
			Appdata.selected_mechanism.old_rom.arom_min,
			Appdata.selected_mechanism.old_rom.arom_max
		]
	else:
		message_label.text = "Starting AROM assessment for Fine Knob...\nPlease rotate the knob through its full range."
		await get_tree().create_timer(0.5).timeout  # Small delay before scene change
		get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_key_knob_selected() -> void:
	Appdata.set_mechanism("Key Knob")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ AROM already completed for KEY KNOB\n(Min: %.2f° | Max: %.2f°)\nSelect another mechanism or go back." % [
			Appdata.selected_mechanism.old_rom.arom_min,
			Appdata.selected_mechanism.old_rom.arom_max
		]
	else:
		message_label.text = "Starting AROM assessment for Key Knob...\nPlease rotate the knob through its full range."
		await get_tree().create_timer(0.5).timeout  # Small delay before scene change
		get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_tripod_grip_pressed() -> void:
	Appdata.set_mechanism("Tripod")

	# Check if assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ Assessment already completed for TRIPOD\n(Compression: %.2f cm to %.2f cm)\nSelect another mechanism or go back." % [
			Appdata.selected_mechanism.old_rom.arom_min,
			Appdata.selected_mechanism.old_rom.arom_max
		]
	else:
		message_label.text = "Starting Tripod Grip assessment...\nPlease squeeze and release the tripod grip."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/tripod_assessment.tscn")

func _on_pinch_button_pressed() -> void:
	message_label.text = "Starting Pinch & Button assessment...\nPlease perform the pinch and button press tests."
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scene/pinch_button_assessment.tscn")

func _on_back_pressed() -> void:
	AppData.current_mechanism = ""
	get_tree().change_scene_to_file("res://scene/main.tscn")
