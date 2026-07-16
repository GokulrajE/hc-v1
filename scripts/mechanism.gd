extends Control

var hand_grip_button: Button
var grip_button: Button
var knob: Button
var fine_knob: Button
var key_knob: Button
var tripod_grip_button: Button
var pinch_button_button: Button
var buttons_button: Button
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
	buttons_button      = get_node_or_null("buttons_button")
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
		pinch_button_button.pressed.connect(_on_pinch_pressed)

	if buttons_button:
		buttons_button.pressed.connect(_on_buttons_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_check_handle_grip_status()


func _check_handle_grip_status() -> void:
	if message_label == null:
		return
	var handle_done := ROM.new("HANDLE", true).is_arom_set()
	var grip_done   := ROM.new("GRIP", true).is_arom_set()
	if handle_done and not grip_done:
		message_label.text = "Handle done — finish the Grip assessment to explore with games."
	elif grip_done and not handle_done:
		message_label.text = "Grip done — finish the Handle assessment to explore with games."


func _on_hand_grip_pressed() -> void:
	var handle_rom := ROM.new("HANDLE", true)
	if handle_rom.is_arom_set():
		var grip_rom := ROM.new("GRIP", true)
		if grip_rom.is_arom_set():
			Appdata.set_mechanism("Handle")
			if message_label:
				message_label.text = "✓ Both Handle & Grip done! Opening Game Selection..."
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://scene/game_selection.tscn")
		else:
			if message_label:
				message_label.text = "✓ Handle done! Finish the Grip assessment to explore with games."
		return
	Appdata.set_mechanism("Handle")
	if message_label:
		message_label.text = "Starting AROM assessment for Handle..."
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scene/handle_assessment.tscn")

func _on_grip_pressed() -> void:
	var grip_rom := ROM.new("GRIP", true)
	if grip_rom.is_arom_set():
		var handle_rom := ROM.new("HANDLE", true)
		if handle_rom.is_arom_set():
			Appdata.set_mechanism("Grip")
			if message_label:
				message_label.text = "✓ Both Handle & Grip done! Opening Game Selection..."
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://scene/game_selection.tscn")
		else:
			if message_label:
				message_label.text = "✓ Grip done! Finish the Handle assessment to explore with games."
		return
	Appdata.set_mechanism("Grip")
	if message_label:
		message_label.text = "Starting Grip Force assessment..."
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scene/grip_assessment.tscn")

func _on_knob_selected() -> void:
	Appdata.set_mechanism("Knob")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ Knob AROM done! Opening Game Selection..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		message_label.text = "Starting AROM assessment for Knob...\nPlease rotate the knob through its full range."
		await get_tree().create_timer(0.5).timeout  # Small delay before scene change
		get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_fine_knob_selected() -> void:
	Appdata.set_mechanism("Fine Knob")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ Fine Knob AROM done! Opening Game Selection..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		message_label.text = "Starting AROM assessment for Fine Knob...\nPlease rotate the knob through its full range."
		await get_tree().create_timer(0.5).timeout  # Small delay before scene change
		get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_key_knob_selected() -> void:
	Appdata.set_mechanism("Key Knob")

	# Check if AROM assessment is already completed
	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ Key Knob AROM done! Opening Game Selection..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		message_label.text = "Starting AROM assessment for Key Knob...\nPlease rotate the knob through its full range."
		await get_tree().create_timer(0.5).timeout  # Small delay before scene change
		get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_tripod_grip_pressed() -> void:
	Appdata.set_mechanism("Tripod")

	if Appdata.selected_mechanism.old_rom and Appdata.selected_mechanism.old_rom.is_arom_set():
		message_label.text = "✓ Tripod AROM done! Opening Game Selection..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		message_label.text = "Starting Tripod Grip assessment...\nPlease squeeze and release the tripod grip."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/tripod_assessment.tscn")

func _on_pinch_pressed() -> void:
	Appdata.set_mechanism("Pinch")
	if Appdata.selected_mechanism.old_rom != null and Appdata.selected_mechanism.old_rom.is_set():
		if message_label:
			message_label.text = "✓ Pinch Assessment done! Opening Game Selection..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		if message_label:
			message_label.text = "Starting Pinch assessment..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/pinch_assessment.tscn")


func _on_buttons_pressed() -> void:
	Appdata.set_mechanism("Buttons")
	if Appdata.selected_mechanism.old_rom != null and Appdata.selected_mechanism.old_rom.is_set():
		if message_label:
			message_label.text = "✓ Buttons Assessment done! Opening Game Selection..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		if message_label:
			message_label.text = "Starting Buttons assessment..."
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/buttons_assessment.tscn")

func _on_back_pressed() -> void:
	Appdata.selected_mechanism = null
	get_tree().change_scene_to_file("res://scene/main.tscn")
