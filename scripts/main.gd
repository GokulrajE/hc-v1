extends Control

var hospital_id_input: LineEdit
var signup_button: Button
var login_button: Button
var diagnostics_button: Button
var device_status_label: Label
var message_label: Label

func _ready() -> void:
	hospital_id_input = get_node_or_null("bg/hospital_id_input")
	signup_button = get_node_or_null("bg/knobs/knob1")
	login_button = get_node_or_null("bg/knobs/knob2")
	diagnostics_button = get_node_or_null("bg/knobs/knob3")
	device_status_label = get_node_or_null("device_status")
	message_label = get_node_or_null("message_label")

	if signup_button:
		signup_button.text = "Signup"
		signup_button.pressed.connect(_on_signup_pressed)

	if login_button:
		login_button.text = "Login"
		login_button.pressed.connect(_on_login_pressed)

	if diagnostics_button:
		diagnostics_button.text = "Diagnostics"
		diagnostics_button.pressed.connect(_on_diagnostics_pressed)

	if HCcomm:
		HCcomm.device_connected.connect(_on_device_connected)
		
	_update_device_status()

func _on_device_connected() -> void:
	_update_device_status()

func _on_device_disconnected() -> void:
	_update_device_status()

func _update_device_status() -> void:
	if device_status_label:
		if HCcomm and HCcomm.device_is_connected:
			device_status_label.text = "Device: CONNECTED"
		else:
			device_status_label.text = "Device: NOT CONNECTED"

func _on_signup_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/signup.tscn")

func _on_login_pressed() -> void:
	if not hospital_id_input:
		if message_label:
			message_label.text = "Hospital ID input not found"
		return

	if not DataManager:
		if message_label:
			message_label.text = "DataManager not available"
		return

	var hospital_id = hospital_id_input.text.strip_edges()
	if hospital_id == "":
		if message_label:
			message_label.text = "Please enter Hospital ID"
		return

	if not DataManager.user_exists(hospital_id):
		if message_label:
			message_label.text = "User not found"
		return

	if not AppData.load_user(hospital_id):
		if message_label:
			message_label.text = "Failed to load user"
		return

	get_tree().change_scene_to_file("res://scene/assessment.tscn")

func _on_diagnostics_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/diagnostics.tscn")

func _attempt_device_connection() -> void:
	if HCcomm and not HCcomm.device_is_connected:
		AppData.open_connection()
	_update_device_status()
