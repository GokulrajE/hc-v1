extends Node2D

var catch_game_button: Button
var safe_crossing_button: Button
var tw_game_button: Button
var back_button: Button
var message_label: Label

func _ready() -> void:
	catch_game_button    = get_node_or_null("catch_game_button")
	safe_crossing_button = get_node_or_null("safe_crossing_button")
	tw_game_button       = get_node_or_null("tw_game_button")
	back_button          = get_node_or_null("back_button")
	message_label        = get_node_or_null("message_label")

	if catch_game_button:
		catch_game_button.pressed.connect(_on_catch_game_pressed)
	if safe_crossing_button:
		safe_crossing_button.pressed.connect(_on_safe_crossing_pressed)
	if tw_game_button:
		tw_game_button.pressed.connect(_on_tw_game_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_update_info()


func _update_info() -> void:
	if message_label == null:
		return
	if Appdata.selected_mechanism == null:
		message_label.text = "No mechanism selected"
		return
	var mech = Appdata.selected_mechanism
	if mech.is_mechanism("Pinch Button"):
		message_label.text = "Mechanism: %s  |  No AROM required — Ready to play!" % mech.name
		return
	var arom = mech.get_current_arom()
	message_label.text = "Mechanism: %s  |  AROM Range: %.2f → %.2f" % [mech.name, arom[0], arom[1]]


func _on_catch_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/catch_game/catch_game.tscn")


func _on_safe_crossing_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/safecrossing/sc_game.tscn")


func _on_tw_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/tablewipping/tw_game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")
