extends Control

var hospital_id_input: LineEdit
var login_button: Button
var back_button: Button
var message_label: Label

func _ready() -> void:
	hospital_id_input = get_node_or_null("hospital_id_input")
	login_button = get_node_or_null("login_button")
	back_button = get_node_or_null("back_button")
	message_label = get_node_or_null("message_label")

	if login_button:
		login_button.pressed.connect(_on_login_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

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

	AppData.current_mechanism = ""
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")
