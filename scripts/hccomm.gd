extends Node

signal new_device_data()
signal device_connected()
signal device_disconnected()

var manager: GdSerialManager
var packet_buffer: PackedByteArray = PackedByteArray()
var device_is_connected: bool = false
var skip_checksum_validation: bool = false
var _active_port: String = ""

# Data format configuration
var data_format: String = ""
var data_types: Array = []
var data_labels: Array = []
var data_size: int = 0

# Format configuration
const FORMAT_CHARS: PackedByteArray = [ord('b'), ord('i'), ord('f')]
const FORMAT_SIZES: Array = [1, 2, 4]

# Extracted device data
var device_data: Array = []
var payload_bytes: PackedByteArray = PackedByteArray()

# Sensor properties
var force_1: float = 0.0
var force_2: float = 0.0
var angle_1: float = 0.0
var angle_2: float = 0.0
var angle_3: float = 0.0
var angle_4: float = 0.0
var distance_1: float = 0.0
var distance_2: float = 0.0
var button_1: int = 0
var button_2: int = 0
var button_3: int = 0
var button_4: int = 0
var button_5: int = 0
var button_6: int = 0
var button_7: int = 0

# Moving average
var moving_average_length: int = 5
var moving_average_counter: int = 0
var moving_average_value: float = 0.0

# Disconnect detection
const DATA_TIMEOUT_SEC: float = 2.5
var _last_data_time: float = 0.0

func _ready():
	load_data_format()
	skip_checksum_validation = true


func _process(delta: float):
	if manager:
		manager.poll_events()

	if device_is_connected:
		_last_data_time += delta
		if _last_data_time >= DATA_TIMEOUT_SEC:
			print("HCComm: no data for %.1fs — device disconnected" % DATA_TIMEOUT_SEC)
			_do_disconnect()


func _exit_tree() -> void:
	if device_is_connected:
		disconnect_device()

func _on_serial_data_received(_port: String, data: PackedByteArray) -> void:
	packet_buffer.append_array(data)
	_parse_packets()

func _parse_packets() -> void:
	var packet_count: int = 0
	while packet_buffer.size() >= 4:  # Minimum packet size: header(2) + size(1) + checksum(1)
		# Look for packet header (0xFF 0xFF)
		if packet_buffer[0] == 0xFF and packet_buffer[1] == 0xFF:
			# Read payload size
			var payload_size: int = packet_buffer[2]

			# Check if payload size is reasonable (should be > 0 and < 256)
			if payload_size == 0 or payload_size > 256:
				print("DEBUG: Invalid payload size: %d, skipping byte" % payload_size)
				packet_buffer = packet_buffer.slice(1)
				continue

			# Check if we have complete packet
			if packet_buffer.size() < (3 + payload_size + 1):
				return  # Not enough data yet

			# Extract payload and checksum
			var payload: PackedByteArray = packet_buffer.slice(3, 3 + payload_size)
			var checksum_received: int = packet_buffer[3 + payload_size]

			# Verify checksum
			var checksum_calc: int = (0xFF + 0xFF + payload_size) & 0xFF
			for byte in payload:
				checksum_calc = (checksum_calc + byte) & 0xFF

			if skip_checksum_validation or checksum_calc == checksum_received:
				payload_bytes = payload
				_update_device_data()
				_last_data_time = 0.0
				new_device_data.emit()
				packet_count += 1
				if packet_count % 100 == 0:
					print("✓ Received %d valid packets" % packet_count)
			else:
				print("DEBUG: Checksum mismatch")
				print("  Header: 0xFF 0xFF")
				print("  Payload size: %d" % payload_size)
				print("  Payload (first 16 bytes): %s" % str(payload.slice(0, 16)))
				print("  Calculated checksum: 0x%02X (%d)" % [checksum_calc, checksum_calc])
				print("  Received checksum: 0x%02X (%d)" % [checksum_received, checksum_received])
				print("  Data format size expected: %d" % data_size)

			# Remove processed packet from buffer
			packet_buffer = packet_buffer.slice(4 + payload_size)
		else:
			# Remove invalid byte and try again
			packet_buffer = packet_buffer.slice(1)

func _update_device_data() -> void:
	# Check payload size matches expected size (allow 1 byte tolerance)
	var payload_size = payload_bytes.size()
	if payload_size != data_size and payload_size - 1 != data_size:
		print("Payload size mismatch: expected %d, got %d" % [data_size, payload_size])
		return

	device_data.clear()
	var byte_index: int = 0

	# Parse payload according to data format
	for i in range(data_types.size()):
		var data_type_byte: int = data_types[i]
		var data_type: String = char(data_type_byte)

		match data_type:
			'b':  # byte
				device_data.append(payload_bytes[byte_index])
				byte_index += 1
			'i':  # uint16
				var value: int = payload_bytes[byte_index] | (payload_bytes[byte_index + 1] << 8)
				device_data.append(value)
				byte_index += 2
			'f':  # float
				var bytes: PackedByteArray = payload_bytes.slice(byte_index, byte_index + 4)
				var value: float = bytes.decode_float(0)
				device_data.append(value)
				byte_index += 4

	# Extract specific sensor values (based on Unity implementation)
	if device_data.size() >= 15:
		force_1 = float(device_data[0])
		force_2 = float(device_data[1])
		angle_1 = float(device_data[2])
		angle_2 = -float(device_data[3])
		angle_3 = -float(device_data[4])
		angle_4 = float(device_data[5])
		distance_1 = float(device_data[6])
		distance_2 = float(device_data[7])
		button_1 = int(device_data[8])
		button_2 = int(device_data[9])
		button_3 = int(device_data[10])
		button_4 = int(device_data[11])
		button_5 = int(device_data[12])
		button_6 = int(device_data[13])
		button_7 = int(device_data[14])

func get_total_force() -> float:
	return force_1 + force_2

func get_btw_distance() -> float:
	return 11.2 - (distance_1 + distance_2)

func get_avg_btw_distance() -> float:
	return _moving_average(get_btw_distance())

func _moving_average(value: float) -> float:
	moving_average_counter += 1

	if moving_average_counter > moving_average_length:
		moving_average_value = moving_average_value + (value - moving_average_value) / (moving_average_length + 1)
	else:
		moving_average_value += value
		if moving_average_counter == moving_average_length:
			moving_average_value = moving_average_value / moving_average_counter

	return moving_average_value

func load_data_format(filename: String = "res://jeditextformat.txt") -> bool:
	# Try to load data format from configuration file
	print("Attempting to load data format from: ", filename)

	var file = FileAccess.open(filename, FileAccess.READ)
	if file == null:
		print("WARNING: Could not load from res:// path, trying absolute path...")
		# Try absolute path instead
		filename = "d:/hc-v-1/jeditextformat.txt"
		file = FileAccess.open(filename, FileAccess.READ)
		if file == null:
			print("ERROR: Data format file not found at: ", filename)
			print("Using default 15 float format (60 bytes)")
			# Use default format: 15 floats
			data_size = 60
			for i in range(15):
				data_types.append(ord('f'))
				data_labels.append("value_%d" % i)
			return true

	data_format = ""
	data_types.clear()
	data_labels.clear()
	data_size = 0

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()

		if line.is_empty():
			continue

		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() < 2:
			continue

		var format_char: String = parts[0]

		# Check if valid format character
		if format_char.length() == 1:
			var char_code: int = ord(format_char)
			var format_index: int = FORMAT_CHARS.find(char_code)

			if format_index >= 0:
				data_format += format_char
				data_types.append(char_code)

				# Label is everything after the first character
				var label: String = " ".join(parts.slice(1))
				data_labels.append(label)

				# Add size based on format character
				data_size += FORMAT_SIZES[format_index]
			else:
				print("Invalid format character: ", format_char)
				return false
		else:
			print("Invalid format character: ", format_char)
			return false

	print("Data format loaded: %s (size: %d)" % [data_format, data_size])
	return true

func get_formatted_data() -> String:
	# Return data in CSV format similar to Unity
	var result: String = ""

	for i in range(device_data.size()):
		var data_type_byte: int = data_types[i] if i < data_types.size() else 0
		var data_type: String = char(data_type_byte)
		var label: String = data_labels[i] if i < data_labels.size() else ""

		match data_type:
			'b':
				result += "%s,%d\n" % [label, int(device_data[i])]
			'i':
				result += "%s,%d\n" % [label, int(device_data[i])]
			'f':
				result += "%s,%.10g\n" % [label, float(device_data[i])]

	return result

func connect_device(port: String, baud: int) -> void:
	print("HCComm: opening %s at %d baud..." % [port, baud])
	if not ClassDB.can_instantiate("GdSerialManager"):
		push_error("GdSerialManager not available")
		device_is_connected = false
		device_disconnected.emit()
		return
	manager = GdSerialManager.new()
	manager.data_received.connect(_on_serial_data_received)
	_active_port = port
	var ok: bool = manager.open(port, baud, 2000)
	if ok:
		print("✓ HCComm: %s opened!" % port)
		device_is_connected = true
		_last_data_time = 0.0
		device_connected.emit()
	else:
		push_error("✗ HCComm: failed to open %s" % port)
		device_is_connected = false
		device_disconnected.emit()

func disconnect_device() -> void:
	_do_disconnect()

func _do_disconnect() -> void:
	if manager and _active_port != "" and manager.is_open(_active_port):
		manager.close(_active_port)
		print("HCComm: %s closed." % _active_port)
	device_is_connected = false
	_last_data_time = 0.0
	device_disconnected.emit()
	manager = null
	_active_port = ""
