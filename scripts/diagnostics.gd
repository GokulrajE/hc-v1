extends Node2D

var status_label: Label
var back_button: Button
var force_data: Label
var angles_data: Label
var distances_data: Label
var buttons_data: Label

var frame_count: int = 0
var update_interval: int = 5

func _ready() -> void:
	status_label = get_node_or_null("Label")
	back_button = get_node_or_null("back_button")
	force_data = get_node_or_null("force_data")
	angles_data = get_node_or_null("angles_data")
	distances_data = get_node_or_null("distances_data")
	buttons_data = get_node_or_null("buttons_data")

	if not status_label:
		print("Error: Could not find status label node")
		return

	status_label.text = "Initializing device communication..."

	if HCcomm and HCcomm.has_signal("device_connected"):
		HCcomm.device_connected.connect(_on_device_connected)

	if HCcomm and HCcomm.has_signal("device_disconnected"):
		HCcomm.device_disconnected.connect(_on_device_disconnected)

	if HCcomm and HCcomm.has_signal("new_device_data"):
		HCcomm.new_device_data.connect(_on_new_device_data)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if HCcomm and HCcomm.device_is_connected:
		status_label.text = "Device: CONNECTED ✓"
	else:
		status_label.text = "Waiting for device connection on %s..." % AppData.COM_PORT



func _process(_delta: float) -> void:
	frame_count += 1

	# Update display periodically
	if frame_count >= update_interval:
		frame_count = 0
		_update_display()

func _on_device_connected() -> void:
	print("Device connected!")
	status_label.text = "Device: CONNECTED ✓"
	_update_display()

func _on_device_disconnected() -> void:
	print("Device disconnected!")
	status_label.text = "Device: NOT CONNECTED - Waiting for device..."

func _on_new_device_data() -> void:
	# Called whenever new device data is received
	_update_display()

func _update_display() -> void:
	if not status_label or not HCcomm:
		return

	if not HCcomm.device_is_connected:
		status_label.text = "Device: NOT CONNECTED - Waiting on %s..." % AppData.COM_PORT
		return

	status_label.text = "Device: CONNECTED ✓"

	# Update Forces
	if force_data:
		force_data.text = "Force 1: %.2f\nForce 2: %.2f\nTotal: %.2f" % [
			HCcomm.force_1,
			HCcomm.force_2,
			HCcomm.get_total_force()
		]

	# Update Angles
	if angles_data:
		angles_data.text = "Angle 1: %.2f° | Angle 2: %.2f°\nAngle 3: %.2f° | Angle 4: %.2f°" % [
			HCcomm.angle_1,
			HCcomm.angle_2,
			HCcomm.angle_3,
			HCcomm.angle_4
		]

	# Update Distances
	if distances_data:
		distances_data.text = "Distance 1: %.2f\nDistance 2: %.2f\nDistance In Between: %.2f" %  [
			HCcomm.distance_1,
			HCcomm.distance_2,
			HCcomm.get_btw_distance()
		]

	# Update Buttons
	if buttons_data:
		var button_text = "Button 1: %s | Button 2: %s | Button 3: %s | Button 4: %s | Button 5: %s\n" % [
			"ON" if HCcomm.button_1 == 0 else "OFF",
			"ON" if HCcomm.button_2 == 0 else "OFF",
			"ON" if HCcomm.button_3 == 0 else "OFF",
			"ON" if HCcomm.button_4 == 0 else "OFF",
			"ON" if HCcomm.button_5 == 0 else "OFF"
		]
		button_text += "Button 6: %s | Button 7: %s" % [
			"ON" if HCcomm.button_6 == 0 else "OFF",
			"ON" if HCcomm.button_7 == 0 else "OFF"
		]
		buttons_data.text = button_text

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")
