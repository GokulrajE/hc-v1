extends Node
class_name Signup

var hospital_id_input: TextEdit
var name_input: TextEdit
var location_input: TextEdit
var age_input: TextEdit
var save_button: Button
var back_button: Button
var limb_left_btn: Button
var limb_right_btn: Button
var status_label: Label
var title_label: Label
var panel: Panel

const FADE_IN_DURATION: float = 0.8
const HOVER_SCALE: float = 1.08
const HOVER_DURATION: float = 0.2
const STATUS_MESSAGE_DURATION: float = 3.0

func _ready() -> void:
	hospital_id_input = get_node_or_null("hospitalID")
	name_input = get_node_or_null("name")
	location_input = get_node_or_null("location")
	age_input = get_node_or_null("age")
	save_button = get_node_or_null("save")
	back_button = get_node_or_null("back_button")
	limb_left_btn = get_node_or_null("limb_container/limb_left")
	limb_right_btn = get_node_or_null("limb_container/limb_right")
	status_label = get_node_or_null("status_label")
	title_label = get_node_or_null("title")
	panel = get_node_or_null("Panel")

	if save_button:
		save_button.pressed.connect(_on_save_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_setup_button_animations()
	#_setup_input_animations()
	_animate_ui_entrance()

func _setup_button_animations() -> void:
	_setup_button_hover(save_button)
	_setup_button_hover(back_button)

func _setup_button_hover(button: Button) -> void:
	if not button:
		return

	button.mouse_entered.connect(func(): _animate_button_hover(button, true))
	button.mouse_exited.connect(func(): _animate_button_hover(button, false))

func _animate_button_hover(button: Button, is_hovering: bool) -> void:
	var target_scale = HOVER_SCALE if is_hovering else 1.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), HOVER_DURATION)

func _setup_input_animations() -> void:
	var input_fields = [hospital_id_input, name_input, age_input, location_input]
	for field in input_fields:
		if field:
			field.focus_entered.connect(func(): _on_input_focus(field, true))
			field.focus_exited.connect(func(): _on_input_focus(field, false))

func _on_input_focus(field: TextEdit, is_focused: bool) -> void:
	var target_color = Color(0.2, 0.8, 1, 0.2) if is_focused else Color(1, 1, 1, 0.1)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(field, "self_modulate", target_color, 0.2)

func _animate_ui_entrance() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	if title_label:
		title_label.modulate.a = 0.0
		tween.tween_property(title_label, "modulate:a", 1.0, FADE_IN_DURATION)

	if panel:
		panel.modulate.a = 0.0
		tween.parallel().tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)

	var input_fields = [hospital_id_input, name_input, age_input, location_input, limb_left_btn, limb_right_btn, save_button, back_button]
	for field in input_fields:
		if field:
			field.modulate.a = 0.0
			tween.parallel().tween_property(field, "modulate:a", 1.0, FADE_IN_DURATION)

	if status_label:
		status_label.modulate.a = 0.0
		tween.parallel().tween_property(status_label, "modulate:a", 1.0, FADE_IN_DURATION)

func _animate_status_message(text: String, color: Color = Color.WHITE) -> void:
	if not status_label:
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	status_label.modulate.a = 0.0
	tween.tween_property(status_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func(): _start_status_fade_out())

func _start_status_fade_out() -> void:
	await get_tree().create_timer(STATUS_MESSAGE_DURATION).timeout
	if not status_label:
		return
	var fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(status_label, "modulate:a", 0.0, 0.3)

func _animate_scene_transition() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(get_parent(), "modulate:a", 0.0, 0.3)

func _on_save_pressed() -> void:
	if not _validate_fields():
		return

	if not Datamanager:
		_animate_status_message("Datamanager not available", Color(1, 0.5, 0.5, 1))
		return

	var hospital_id = hospital_id_input.text.strip_edges()

	if Datamanager.user_exists(hospital_id):
		_animate_status_message("User already exists!", Color(1, 0.5, 0.5, 1))
		return

	if not Datamanager.create_file_structure(hospital_id):
		_animate_status_message("Failed to create file structure", Color(1, 0.5, 0.5, 1))
		return

	if not Datamanager.create_session_file(hospital_id):
		_animate_status_message("Failed to create session file", Color(1, 0.5, 0.5, 1))
		return

	var config_data = {
		"DateTime": Datamanager.get_formatted_datetime(),
		"HospitalID": hospital_id,
		"Name": name_input.text.strip_edges(),
		"Age": age_input.text.strip_edges(),
		"Location": location_input.text.strip_edges(),
		"AffectedLimb": ("Right" if limb_right_btn and limb_right_btn.button_pressed else "Left"),
	}

	if not Datamanager.save_config(config_data):
		_animate_status_message("Failed to save config", Color(1, 0.5, 0.5, 1))
		return

	if not Datamanager.user_exists(hospital_id):
		_animate_status_message("Failed to load user", Color(1, 0.5, 0.5, 1))
		return

	_animate_status_message("✅ Registration successful! Redirecting...", Color(0.2, 1, 0.4, 1))
	_animate_scene_transition()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _on_back_pressed() -> void:
	_animate_scene_transition()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _validate_fields() -> bool:
	if not hospital_id_input or hospital_id_input.text.strip_edges() == "":
		_animate_status_message("⚠️ Hospital ID required", Color(1, 0.8, 0.2, 1))
		return false

	if not name_input or name_input.text.strip_edges() == "":
		_animate_status_message("⚠️ Patient Name required", Color(1, 0.8, 0.2, 1))
		return false

	if not location_input or location_input.text.strip_edges() == "":
		_animate_status_message("⚠️ Location required", Color(1, 0.8, 0.2, 1))
		return false

	if not age_input or age_input.text.strip_edges() == "":
		_animate_status_message("⚠️ Age required", Color(1, 0.8, 0.2, 1))
		return false

	return true
