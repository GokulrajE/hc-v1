extends Node2D

var user_info_label: Label
var back_button: Button

func _ready() -> void:
	user_info_label = get_node_or_null("user_info")
	back_button = get_node_or_null("back_button")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_display_user_info()

func _display_user_info() -> void:
	if not user_info_label:
		return

	var text = "=== User Information ===\n\n"
	text += "Hospital ID: %s\n" % AppData.hospital_id
	text += "Name: %s\n" % AppData.user_name
	text += "Affected Limb: %s\n" % AppData.affected_limb
	text += "Session: %d\n" % AppData.session_number
	text += "\n=== Session Details ===\n"
	text += "Trial Number (Day): %d\n" % AppData.trial_number_day
	text += "Trial Number (Session): %d\n" % AppData.trial_number_session
	text += "Cumulative Targets: %d\n" % AppData.cumulative_targets
	text += "Cumulative Hits: %d\n" % AppData.cumulative_hits
	text += "Cumulative Misses: %d\n" % AppData.cumulative_misses

	user_info_label.text = text

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")
