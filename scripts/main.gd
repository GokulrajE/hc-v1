extends Control

# ── existing scene node refs ─────────────────────────────────────────────────
var hospital_id_input    : LineEdit
var signup_button        : Button
var login_button         : Button
var diagnostics_button   : Button
var device_status_label  : Label
var message_label        : Label
var connection_status    : TextureRect
var hyper_cube_animation : AnimatedSprite2D
var title_label          : Label
var panel                : Panel

# ── connection panel ──────────────────────────────────────────────────────────
var _device_panel : Panel
var _scan_content : Control
var _scan_lbl     : Label
var _port_list    : VBoxContainer
var _rescan_btn   : Button
var _disc_btn     : Button
var _pulse_tween  : Tween
var _scan_thread  : Thread

# ── constants ─────────────────────────────────────────────────────────────────
const COLOR_CONNECTED    : Color = Color(0.216, 0.941, 0.094, 1)
const COLOR_DISCONNECTED : Color = Color(1.0,  0.2,   0.2,   1)
const FADE_IN_DURATION   : float = 0.8
const HOVER_SCALE        : float = 1.08
const HOVER_DURATION     : float = 0.2
const COLOR_TRANSITION   : float = 0.5


func _ready() -> void:
	hospital_id_input    = get_node_or_null("bg/hospital_id_input")
	signup_button        = get_node_or_null("bg/signup")
	login_button         = get_node_or_null("bg/login")
	diagnostics_button   = get_node_or_null("bg/diagnostics")
	device_status_label  = get_node_or_null("device_status")
	message_label        = get_node_or_null("message_label")
	connection_status    = get_node_or_null("connectionStatus")
	hyper_cube_animation = get_node_or_null("bg/hyper_cube_annimation")
	title_label          = get_node_or_null("title")
	panel                = get_node_or_null("bg/Panel")
	_device_panel        = get_node_or_null("bg/device_panel")
	_scan_content        = get_node_or_null("bg/device_panel/scan_content")
	_scan_lbl            = get_node_or_null("bg/device_panel/scan_content/scan_lbl")
	_rescan_btn          = get_node_or_null("bg/device_panel/scan_content/header_row/rescan_btn")
	_port_list           = get_node_or_null("bg/device_panel/scan_content/scroll/port_list")
	_disc_btn            = get_node_or_null("bg/disc_btn")

	if login_button:       login_button.disabled       = true
	if diagnostics_button: diagnostics_button.disabled = true
	if _rescan_btn:        _rescan_btn.pressed.connect(_start_scan)
	if _disc_btn:          _disc_btn.pressed.connect(func(): HCcomm.disconnect_device())

	_setup_button_animations()
	_animate_ui_entrance()

	if HCcomm:
		HCcomm.device_connected.connect(_on_device_connected)
		HCcomm.device_disconnected.connect(_on_device_disconnected)

	_update_device_status()

	if hyper_cube_animation:
		hyper_cube_animation.play()

	if HCcomm and HCcomm.device_is_connected:
		if login_button:       login_button.disabled       = false
		if diagnostics_button: diagnostics_button.disabled = false
		_show_connected_state()
	else:
		_start_scan()


func _exit_tree() -> void:
	if _scan_thread and _scan_thread.is_started():
		_scan_thread.wait_to_finish()


# ── Panel state ───────────────────────────────────────────────────────────────


func _show_scan_state() -> void:
	_device_panel.visible = true
	_disc_btn.visible     = false


func _show_connected_state() -> void:
	_device_panel.visible = false
	_disc_btn.visible     = true


# ── Scan (threaded) ───────────────────────────────────────────────────────────

func _start_scan() -> void:
	if _scan_thread and _scan_thread.is_started():
		return
	if HCcomm and HCcomm.device_is_connected:
		return
	_scan_lbl.text = "Scanning..."
	_rescan_btn.disabled = true
	for child in _port_list.get_children():
		child.queue_free()

	_scan_thread = Thread.new()
	_scan_thread.start(_scan_ports_thread)


func _scan_ports_thread() -> void:
	var ports := _query_serial_ports()
	call_deferred("_on_scan_done", ports)


func _on_scan_done(ports: Array) -> void:
	if _scan_thread:
		_scan_thread.wait_to_finish()
	_rescan_btn.disabled = false
	_populate_port_list(ports)


func _query_serial_ports() -> Array:
	if OS.get_name() != "Windows":
		return []

	# Find paired Bluetooth devices named "hypercube", extract their MAC from the instance ID.
	# COM port instance IDs for Bluetooth also contain the same MAC — match them to mark IsHC.
	var output: Array = []
	var cmd := (
		"try{"
		+ "$hcDevs=@{};"
		+ "Get-PnpDevice -Class Bluetooth -EA SilentlyContinue"
		+   "|Where-Object{$_.FriendlyName -match '(?i)hypercube'}"
		+   "|ForEach-Object{"
		+     "if($_.InstanceId -match '([0-9A-Fa-f]{12})'){"
		+       "$hcDevs[$Matches[1].ToUpper()]=$_.FriendlyName"
		+     "}"
		+   "};"
		+ "$r=Get-PnpDevice -Class Ports -Status OK -EA SilentlyContinue|ForEach-Object{"
		+   "$port=[regex]::Match($_.FriendlyName,'COM\\d+').Value;"
		+   "if($port){"
		+     "$isHC=$false;$dname=$_.FriendlyName;"
		+     "foreach($mac in $hcDevs.Keys){"
		+       "if($_.InstanceId -match $mac){"
		+         "$isHC=$true;$dname=$hcDevs[$mac]+' ('+$port+')';break"
		+       "}"
		+     "};"
		+     "[PSCustomObject]@{Port=$port;Name=$dname;IsHC=$isHC}"
		+   "}"
		+ "};"
		+ "if($r){$r|ConvertTo-Json -Compress}else{'[]'}"
		+ "}catch{'[]'}"
	)
	OS.execute("powershell", ["-NonInteractive", "-Command", cmd], output, true)

	if output.is_empty():
		return []

	var raw: String = output[0].strip_edges()
	if raw == "" or raw == "[]" or raw == "null":
		return []

	var json := JSON.new()
	if json.parse(raw) != OK:
		return []

	var data = json.get_data()
	if data == null:
		return []
	if data is Dictionary:
		data = [data]

	var ports: Array = []
	for item in data:
		if item is Dictionary:
			var port: String = item.get("Port", "")
			if port == "":
				continue
			var dev_name: String = item.get("Name", port)
			var is_hc: bool = item.get("IsHC", false)
			ports.append({"name": dev_name, "port": port, "is_hc": is_hc})

	ports = ports.filter(func(p): return p.is_hc)
	return ports


func _populate_port_list(ports: Array) -> void:
	for child in _port_list.get_children():
		child.queue_free()

	if ports.is_empty():
		_scan_lbl.text = "No HyperCube found — is it paired?"
		return

	_scan_lbl.text = "%d HyperCube port(s) found" % ports.size()

	for port_info: Dictionary in ports:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_port_list.add_child(row)

		# Status dot
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 16)
		dot.add_theme_color_override("font_color",
			Color(0.2, 0.9, 0.3, 1) if port_info.is_hc else Color(0.45, 0.45, 0.5, 1))
		dot.custom_minimum_size = Vector2(18, 0)
		dot.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
		row.add_child(dot)

		# Name label
		var lbl := Label.new()
		var disp: String = port_info.name if port_info.name != "" else port_info.port
		lbl.text = disp
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color",
			Color(0.85, 1.0, 0.85, 1) if port_info.is_hc else Color(0.72, 0.72, 0.76, 1))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		row.add_child(lbl)

		# Connect button
		var btn := Button.new()
		btn.text = port_info.port
		btn.custom_minimum_size = Vector2(80, 32)
		btn.add_theme_font_size_override("font_size", 16)
		var col := Color(0.1, 0.5, 0.1, 1) if port_info.is_hc else Color(0.2, 0.2, 0.35, 1)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_top_left     = 8
		sb.corner_radius_top_right    = 8
		sb.corner_radius_bottom_right = 8
		sb.corner_radius_bottom_left  = 8
		btn.add_theme_stylebox_override("normal", sb)
		var sbh := StyleBoxFlat.new()
		sbh.bg_color = col.lightened(0.2)
		sbh.corner_radius_top_left     = 8
		sbh.corner_radius_top_right    = 8
		sbh.corner_radius_bottom_right = 8
		sbh.corner_radius_bottom_left  = 8
		btn.add_theme_stylebox_override("hover",   sbh)
		btn.add_theme_stylebox_override("pressed", sbh)
		var p: String = port_info.port
		btn.pressed.connect(func(): _do_connect(p))
		row.add_child(btn)

		var sep := HSeparator.new()
		sep.add_theme_color_override("color", Color(1, 1, 1, 0.07))
		_port_list.add_child(sep)


func _do_connect(port: String) -> void:
	_scan_lbl.text = "Connecting to %s..." % port
	_start_pulse()
	Appdata.initialize_connection(port)


func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_scan_lbl, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_scan_lbl, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _scan_lbl:
		_scan_lbl.modulate.a = 1.0


# ── HCComm signal handlers ────────────────────────────────────────────────────

func _on_device_connected() -> void:
	_stop_pulse()
	if login_button:       login_button.disabled = false
	if diagnostics_button: diagnostics_button.disabled = false
	_show_connected_state()
	_update_device_status()


func _on_device_disconnected() -> void:
	_stop_pulse()
	if login_button:       login_button.disabled = true
	if diagnostics_button: diagnostics_button.disabled = true
	_show_scan_state()
	_update_device_status()
	_start_scan()


func _update_device_status() -> void:
	if device_status_label == null:
		return
	if HCcomm and HCcomm.device_is_connected:
		device_status_label.text = "Device: CONNECTED"
		_animate_connection_color(COLOR_CONNECTED)
	else:
		device_status_label.text = "Device: NOT CONNECTED"
		_animate_connection_color(COLOR_DISCONNECTED)


func _animate_connection_color(target_color: Color) -> void:
	if not connection_status:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(connection_status, "self_modulate", target_color, COLOR_TRANSITION)


# ── Button hover + entrance ───────────────────────────────────────────────────

func _setup_button_animations() -> void:
	_setup_button_hover(signup_button)
	_setup_button_hover(login_button)
	_setup_button_hover(diagnostics_button)
	if signup_button:      signup_button.pressed.connect(_on_signup_pressed)
	if login_button:       login_button.pressed.connect(_on_login_pressed)
	if diagnostics_button: diagnostics_button.pressed.connect(_on_diagnostics_pressed)


func _setup_button_hover(button: Button) -> void:
	if not button:
		return
	button.mouse_entered.connect(func(): _animate_button_hover(button, true))
	button.mouse_exited.connect( func(): _animate_button_hover(button, false))


func _animate_button_hover(button: Button, is_hovering: bool) -> void:
	var s := HOVER_SCALE if is_hovering else 1.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(s, s), HOVER_DURATION)


func _animate_ui_entrance() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for node: CanvasItem in [title_label, panel, signup_button, login_button,
							 device_status_label, diagnostics_button, hyper_cube_animation]:
		if node:
			node.modulate.a = 0.0
			tween.parallel().tween_property(node, "modulate:a", 1.0, FADE_IN_DURATION)


# ── Message helper ────────────────────────────────────────────────────────────

func _animate_message(text: String) -> void:
	if not message_label:
		return
	message_label.text      = text
	message_label.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func(): _start_message_fade_out())


func _start_message_fade_out() -> void:
	await get_tree().create_timer(2.0).timeout
	if not message_label:
		return
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.3)


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_signup_pressed() -> void:
	_animate_scene_transition()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scene/signup.tscn")


func _on_login_pressed() -> void:
	if not hospital_id_input:
		_animate_message("Hospital ID input not found")
		return
	var hospital_id := hospital_id_input.text.strip_edges()
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
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
