extends Node2D

var hospital_id_input: TextEdit
var name_input: TextEdit
var location_input: TextEdit
var age_input: TextEdit
var save_button: Button
var back_button: Button
var limb_input: OptionButton
var status_label: Label

func _ready() -> void:
	hospital_id_input = get_node_or_null("hospitalID")
	name_input = get_node_or_null("name")
	location_input = get_node_or_null("location")
	age_input = get_node_or_null("age")
	save_button = get_node_or_null("save")
	back_button = get_node_or_null("back_button")
	limb_input = get_node_or_null("limb")
	status_label = get_node_or_null("status_label")

	if save_button:
		save_button.pressed.connect(_on_save_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_save_pressed() -> void:
	if not _validate_fields():
		return

	if not DataManager:
		if status_label:
			status_label.text = "DataManager not available"
		return

	var hospital_id = hospital_id_input.text.strip_edges()

	if DataManager.user_exists(hospital_id):
		if status_label:
			status_label.text = "User already exists!"
		return

	if not DataManager.create_file_structure(hospital_id):
		if status_label:
			status_label.text = "Failed to create file structure"
		return

	if not DataManager.create_session_file(hospital_id):
		if status_label:
			status_label.text = "Failed to create session file"
		return

	var config_data = {
		"HospitalID": hospital_id,
		"Name": name_input.text.strip_edges(),
		"Age": age_input.text.strip_edges(),
		"Location": location_input.text.strip_edges(),
		"AffectedLimb": limb_input.get_item_text(limb_input.selected) if limb_input else "Unknown",
		"DevicePort": "COM15",
		"CreatedDate": Time.get_datetime_string_from_system()
	}

	if not DataManager.save_config(config_data):
		if status_label:
			status_label.text = "Failed to save config"
		return

	if not AppData.load_user(hospital_id):
		if status_label:
			status_label.text = "Failed to load user"
		return

	get_tree().change_scene_to_file("res://scene/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _validate_fields() -> bool:
	if not hospital_id_input or hospital_id_input.text.strip_edges() == "":
		if status_label:
			status_label.text = "Hospital ID required"
		return false

	if not name_input or name_input.text.strip_edges() == "":
		if status_label:
			status_label.text = "Name required"
		return false

	if not location_input or location_input.text.strip_edges() == "":
		if status_label:
			status_label.text = "Location required"
		return false

	if not age_input or age_input.text.strip_edges() == "":
		if status_label:
			status_label.text = "Age required"
		return false

	return true
