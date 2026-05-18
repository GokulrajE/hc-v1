extends Node2D

var hccomm
var status_label: Label

var frame_count: int = 0
var update_interval: int = 5  # Update display every 5 frames

func _ready() -> void:
	# Get status label
	status_label = get_node_or_null("bg/Label")
	if not status_label:
		print("Error: Could not find Label node at bg/Label")
		return

	status_label.text = "Initializing device communication..."

	# Create HCComm node dynamically
	hccomm = Node.new()
	hccomm.set_script(load("res://scripts/hccomm.gd"))
	hccomm.name = "HCComm"
	add_child(hccomm)

	print("HCComm node created and added as child")

	# Wait a frame for HCComm to initialize
	await get_tree().process_frame

	# Connect to device signals
	if hccomm and hccomm.has_signal("device_connected"):
		hccomm.device_connected.connect(_on_device_connected)
		print("Connected to device_connected signal")

	if hccomm and hccomm.has_signal("device_disconnected"):
		hccomm.device_disconnected.connect(_on_device_disconnected)
		print("Connected to device_disconnected signal")

	if hccomm and hccomm.has_signal("new_device_data"):
		hccomm.new_device_data.connect(_on_new_device_data)
		print("Connected to new_device_data signal")

	# Update initial status
	if hccomm and hccomm.device_is_connected:
		status_label.text = "Device: CONNECTED"
	else:
		status_label.text = "Device: NOT CONNECTED\nWaiting for device connection on COM15..."

	print("Diagnostics initialized")



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
	if not status_label or not hccomm:
		return

	if not hccomm.device_is_connected:
		status_label.text = "Device: NOT CONNECTED\nWaiting for device connection on COM3..."
		return

	var text = "=== HyperCube Device Diagnostics ===\n"
	text += "Status: CONNECTED\n\n"

	# Forces
	text += "FORCES:\n"
	text += "  Force 1: %.2f\n" % hccomm.force_1
	text += "  Force 2: %.2f\n" % hccomm.force_2
	text += "  Total: %.2f\n\n" % hccomm.get_total_force()

	# Angles
	text += "ANGLES:\n"
	text += "  Angle 1: %.2f°\n" % hccomm.angle_1
	text += "  Angle 2: %.2f°\n" % hccomm.angle_2
	text += "  Angle 3: %.2f°\n" % hccomm.angle_3
	text += "  Angle 4: %.2f°\n\n" % hccomm.angle_4

	# Distances
	text += "DISTANCES:\n"
	text += "  Distance 1: %.2f\n" % hccomm.distance_1
	text += "  Distance 2: %.2f\n" % hccomm.distance_2
	text += "  Between: %.2f\n" % hccomm.get_btw_distance()
	text += "  Avg Between: %.2f\n\n" % hccomm.get_avg_btw_distance()

	# Buttons
	text += "BUTTONS: "
	text += "%d %d %d %d %d %d %d\n" % [
		hccomm.button_1, hccomm.button_2, hccomm.button_3, hccomm.button_4,
		hccomm.button_5, hccomm.button_6, hccomm.button_7
	]

	status_label.text = text
