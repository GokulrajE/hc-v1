extends Control

var hospital_id_input: LineEdit
var signup_button: Button
var login_button: Button
var diagnostics_button: Button
var device_status_label: Label
var message_label: Label
var connection_status: TextureRect



# Color constants
const COLOR_CONNECTED: Color = Color(0.21568628, 0.9411765, 0.09411765, 1)  # Green
const COLOR_DISCONNECTED: Color = Color(1.0, 0.2, 0.2, 1)  # Red
const COLOR_CONNECTING: Color = Color(1.0, 0.65, 0.0, 1)  # Orange

func _ready() -> void:
	hospital_id_input = get_node_or_null("bg/hospital_id_input")
	signup_button = get_node_or_null("bg/signup")
	login_button = get_node_or_null("bg/login")
	diagnostics_button = get_node_or_null("bg/diagnostics")
	device_status_label = get_node_or_null("device_status")
	message_label = get_node_or_null("message_label")
	connection_status = get_node_or_null("connectionStatus")

	if signup_button:
		signup_button.text = "Signup"
		signup_button.pressed.connect(_on_signup_pressed)

	if login_button:
		login_button.text = "Login"
		login_button.pressed.connect(_on_login_pressed)

	if diagnostics_button:
		diagnostics_button.text = "Diagnostics"
		diagnostics_button.pressed.connect(_on_diagnostics_pressed)
	# Initialize AppData and connect to device
	if HCcomm and not HCcomm.device_is_connected:
		Appdata.initialize_connection()
	
	if HCcomm:
		HCcomm.device_connected.connect(_on_device_connected)
		HCcomm.device_disconnected.connect(_on_device_disconnected)

	_update_device_status()

	
	

func _on_device_connected() -> void:
	_update_device_status()

func _on_device_disconnected() -> void:
	_update_device_status()

func _update_device_status() -> void:
	if device_status_label:
		if HCcomm and HCcomm.device_is_connected:
			device_status_label.text = "Device: CONNECTED"
			_set_connection_color(COLOR_CONNECTED)
		elif HCcomm and not HCcomm.device_is_connected:
			device_status_label.text = "Device: NOT CONNECTED"
			_set_connection_color(COLOR_DISCONNECTED)

func _set_connection_color(color: Color) -> void:
	if connection_status:
		connection_status.self_modulate = color

func _on_signup_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/signup.tscn")

func _on_login_pressed() -> void:
	if not hospital_id_input:
		if message_label:
			message_label.text = "Hospital ID input not found"
		return

	

	var hospital_id = hospital_id_input.text.strip_edges()
	if hospital_id == "":
		if message_label:
			message_label.text = "Please enter Hospital ID"
		return

	if not Datamanager.user_exists(hospital_id):
		if message_label:
			message_label.text = "User not found"
		return

	# Initialize user data in AppData
	Appdata.initilize_user(hospital_id)

	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _on_diagnostics_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/diagnostics.tscn")
