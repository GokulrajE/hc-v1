extends Node2D

var title_label: Label
var start_button: Button
var back_button: Button
var knob_buttons_container: HBoxContainer
var knob_button: Button
var fine_knob_button: Button
var key_knob_button: Button

func _ready() -> void:
	title_label = get_node_or_null("title")
	start_button = get_node_or_null("start_button")
	back_button = get_node_or_null("back_button")
	knob_buttons_container = get_node_or_null("knob_buttons_container")
	knob_button = get_node_or_null("knob_buttons_container/knob_button")
	fine_knob_button = get_node_or_null("knob_buttons_container/fine_knob_button")
	key_knob_button = get_node_or_null("knob_buttons_container/key_knob_button")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if knob_button:
		knob_button.pressed.connect(_on_knob_selected)
	if fine_knob_button:
		fine_knob_button.pressed.connect(_on_fine_knob_selected)
	if key_knob_button:
		key_knob_button.pressed.connect(_on_key_knob_selected)

	_update_title()
	_update_ui()

func _update_title() -> void:
	if not title_label:
		return

	if AppData.current_mechanism != "":
		title_label.text = "ASSESS %s" % AppData.current_mechanism
	else:
		title_label.text = "Assessment"


func _update_ui() -> void:
	if "Knobs" in AppData.current_mechanism:
		if start_button:
			start_button.visible = false
		if knob_buttons_container:
			knob_buttons_container.visible = true
	else:
		if start_button:
			start_button.visible = true
		if knob_buttons_container:
			knob_buttons_container.visible = false

func _on_knob_selected() -> void:

	Appdata.set_mechanism("Knob")
	get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_fine_knob_selected() -> void:

	Appdata.set_mechanism("Fine Knob")

	get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")

func _on_key_knob_selected() -> void:
	
	Appdata.set_mechanism("Key Knob")	
	
	get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")



func _on_back_pressed() -> void:
	if AppData.current_mechanism != "":
		AppData.current_mechanism = ""
		get_tree().change_scene_to_file("res://scene/mechanism.tscn")
	else:
		get_tree().change_scene_to_file("res://scene/main.tscn")
