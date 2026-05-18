extends Node2D


var status_label: Label
var back_button: Button

var frame_count: int = 0
var update_interval: int = 5

func _ready() -> void:
	status_label = get_node_or_null("bg/Label")
	back_button = get_node_or_null("back_button")
	if not status_label:
		print("Error: Could not find Label node at bg/Label")
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
		status_label.text = "Device: CONNECTED"
	else:
		status_label.text = "Device: NOT CONNECTED\nWaiting for device connection on %s..." % AppData.COM_PORT



func _process(_delta: float) -> void:
	frame_count += 1

	# Update display periodically
	if frame_count >= update_interval:
		frame_count = 0
		_update_display()

func _on_device_connected() -> void:
	print("Device connected!")
	status_label.text = "Device: CONNECTED"
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
		status_label.text = "Device: NOT CONNECTED\nWaiting on %s..." % AppData.COM_PORT
		return

	var text = "=== HyperCube Device Diagnostics ===\n"
	text += "Status: CONNECTED\n\n"

	# Forces
	text += "FORCES:\n"
	text += "  Force 1: %.2f\n" % HCcomm.force_1
	text += "  Force 2: %.2f\n" % HCcomm.force_2
	text += "  Total: %.2f\n\n" % HCcomm.get_total_force()

	# Angles
	text += "ANGLES:\n"
	text += "  Angle 1: %.2f°\n" % HCcomm.angle_1
	text += "  Angle 2: %.2f°\n" % HCcomm.angle_2
	text += "  Angle 3: %.2f°\n" % HCcomm.angle_3
	text += "  Angle 4: %.2f°\n\n" % HCcomm.angle_4

	# Distances
	text += "DISTANCES:\n"
	text += "  Distance 1: %.2f\n" % HCcomm.distance_1
	text += "  Distance 2: %.2f\n" % HCcomm.distance_2
	text += "  Between: %.2f\n" % HCcomm.get_btw_distance()
	text += "  Avg Between: %.2f\n\n" % HCcomm.get_avg_btw_distance()

	# Buttons
	text += "BUTTONS: "
	text += "%d %d %d %d %d %d %d\n" % [
		HCcomm.button_1, HCcomm.button_2, HCcomm.button_3, HCcomm.button_4,
		HCcomm.button_5, HCcomm.button_6, HCcomm.button_7
	]

	status_label.text = text

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")
