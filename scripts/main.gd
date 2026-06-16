extends Control

var hospital_id_input: LineEdit
var signup_button: Button
var login_button: Button
var diagnostics_button: Button
var device_status_label: Label
var message_label: Label
var connection_status: TextureRect
var hyper_cube_animation: AnimatedSprite2D
var title_label: Label
var panel: Panel

# Color constants
const COLOR_CONNECTED: Color = Color(0.21568628, 0.9411765, 0.09411765, 1)
const COLOR_DISCONNECTED: Color = Color(1.0, 0.2, 0.2, 1)
const COLOR_CONNECTING: Color = Color(1.0, 0.65, 0.0, 1)

# Animation constants
const FADE_IN_DURATION: float = 0.8
const HOVER_SCALE: float = 1.08
const HOVER_DURATION: float = 0.2
const COLOR_TRANSITION_DURATION: float = 0.5

func _ready() -> void:
	hospital_id_input = get_node_or_null("bg/hospital_id_input")
	signup_button = get_node_or_null("bg/signup")
	login_button = get_node_or_null("bg/login")
	diagnostics_button = get_node_or_null("bg/diagnostics")
	device_status_label = get_node_or_null("device_status")
	message_label = get_node_or_null("message_label")
	connection_status = get_node_or_null("connectionStatus")
	hyper_cube_animation = get_node_or_null("bg/hyper_cube_annimation")
	title_label = get_node_or_null("title")
	panel = get_node_or_null("bg/Panel")

	_setup_button_animations()
	_animate_ui_entrance()

	if HCcomm and not HCcomm.device_is_connected:
		Appdata.initialize_connection()

	if HCcomm:
		HCcomm.device_connected.connect(_on_device_connected)
		HCcomm.device_disconnected.connect(_on_device_disconnected)

	_update_device_status()

	if hyper_cube_animation:
		hyper_cube_animation.play()

func _setup_button_animations() -> void:
	_setup_button_hover(signup_button)
	_setup_button_hover(login_button)
	_setup_button_hover(diagnostics_button)

	if signup_button:
		signup_button.pressed.connect(_on_signup_pressed)

	if login_button:
		login_button.pressed.connect(_on_login_pressed)

	if diagnostics_button:
		diagnostics_button.pressed.connect(_on_diagnostics_pressed)

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

	if signup_button:
		signup_button.modulate.a = 0.0
		tween.parallel().tween_property(signup_button, "modulate:a", 1.0, FADE_IN_DURATION)

	if login_button:
		login_button.modulate.a = 0.0
		tween.parallel().tween_property(login_button, "modulate:a", 1.0, FADE_IN_DURATION)

	if device_status_label:
		device_status_label.modulate.a = 0.0
		tween.parallel().tween_property(device_status_label, "modulate:a", 1.0, FADE_IN_DURATION)

	if diagnostics_button:
		diagnostics_button.modulate.a = 0.0
		tween.parallel().tween_property(diagnostics_button, "modulate:a", 1.0, FADE_IN_DURATION)

	if hyper_cube_animation:
		hyper_cube_animation.modulate.a = 0.0
		tween.parallel().tween_property(hyper_cube_animation, "modulate:a", 1.0, FADE_IN_DURATION)

func _on_device_connected() -> void:
	_update_device_status()

func _on_device_disconnected() -> void:
	_update_device_status()

func _update_device_status() -> void:
	if device_status_label:
		if HCcomm and HCcomm.device_is_connected:
			device_status_label.text = "Device: CONNECTED"
			_animate_connection_color(COLOR_CONNECTED)
		elif HCcomm and not HCcomm.device_is_connected:
			device_status_label.text = "Device: NOT CONNECTED"
			_animate_connection_color(COLOR_DISCONNECTED)

func _animate_connection_color(target_color: Color) -> void:
	if not connection_status:
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(connection_status, "self_modulate", target_color, COLOR_TRANSITION_DURATION)

func _animate_message(text: String) -> void:
	if not message_label:
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	message_label.text = text
	message_label.modulate.a = 0.0
	tween.tween_property(message_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func(): _start_message_fade_out())

func _start_message_fade_out() -> void:
	await get_tree().create_timer(2.0).timeout
	if not message_label:
		return
	var fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)

func _on_signup_pressed() -> void:
	_animate_scene_transition()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scene/signup.tscn")

func _on_login_pressed() -> void:
	if not hospital_id_input:
		_animate_message("Hospital ID input not found")
		return

	var hospital_id = hospital_id_input.text.strip_edges()
	if hospital_id == "":
		_animate_message("Please enter Hospital ID")
		return

	if not Datamanager.user_exists(hospital_id):
		_animate_message("User not found")
		return

	Appdata.initilize_user(hospital_id)
	_animate_scene_transition()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _on_diagnostics_pressed() -> void:
	_animate_scene_transition()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scene/diagnostics.tscn")

func _animate_scene_transition() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
