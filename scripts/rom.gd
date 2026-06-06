extends Node
class_name ROM

# ROM File header for CSV (HyperCube only stores AROM data)
const FILEHEADER = ["DateTime", "AromMin", "AromMax", "ReachingTime"]

# Class attributes to store ROM data (AROM only for HyperCube)
var datetime: String = ""
var arom_min: float = 0.0
var arom_max: float = 0.0
var reaching_time: float = 0.0
var mechanism: String = ""

func _init(mechanism_name: String = "", read_from_file: bool = true) -> void:
	mechanism = mechanism_name
	if read_from_file and mechanism_name != "":
		read_from_file_internal(mechanism_name)
	else:
		reset_values()

# Check if AROM is set (not all zeros)
func is_arom_set() -> bool:
	return arom_min != 0.0 or arom_max != 0.0

# Check if ROM is set (AROM only for HyperCube)
func is_set() -> bool:
	return is_arom_set()

# Set AROM values with optional reaching time
func set_arom(min_val: float, max_val: float, reach_time: float = 0.0) -> void:
	arom_min = min_val
	arom_max = max_val
	reaching_time = reach_time
	datetime = Datamanager.get_formatted_datetime()

# Set mechanism name
func set_mechanism(mech: String) -> void:
	if mechanism == "":
		mechanism = mech

# Reset all ROM values to 0
func reset_values() -> void:
	arom_min = 0.0
	arom_max = 0.0
	reaching_time = 0.0
	datetime = ""

# Get current AROM as array
func get_current_arom() -> Array:
	return [arom_min, arom_max]

# Write ROM data to CSV file
func write_to_assessment_file() -> bool:
	if mechanism == "":
		push_error("ROM: Cannot write assessment file without mechanism name")
		return false

	var rom_file_path = Datamanager.get_rom_file_path(mechanism)
	if rom_file_path == "":
		push_error("ROM: Failed to get ROM file path")
		return false

	# Construct rom directory path
	var rom_dir = Datamanager.get_user_path(Appdata.user_data.hospital_id) + "rom/"

	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(rom_dir):
		var error = DirAccess.make_dir_recursive_absolute(rom_dir)
		if error != OK:
			push_error("ROM: Failed to create ROM directory: %s" % rom_dir)
			return false

	# Check if file exists, if not create with header
	if not FileAccess.file_exists(rom_file_path):
		var preheader = ""
		preheader += ":Location: %s\n" % Appdata.user_data.location
		preheader += ":Device: %s\n" % Appdata.device_name
		preheader += ":User: %s\n" % Appdata.user_data.hospital_id
		preheader += ",".join(FILEHEADER) + "\n"

		var rom_file = FileAccess.open(rom_file_path, FileAccess.WRITE)
		if rom_file == null:
			push_error("ROM: Failed to create ROM file: %s" % rom_file_path)
			return false
		rom_file.store_string(preheader)

	# Append ROM data row
	var row = "%s,%s,%s,%s" % [
		datetime,
		str(arom_min),
		str(arom_max),
		str(reaching_time)
	]

	var rom_file = FileAccess.open(rom_file_path, FileAccess.READ_WRITE)
	if rom_file == null:
		push_error("ROM: Failed to open ROM file for writing: %s" % rom_file_path)
		return false
	rom_file.seek_end()
	rom_file.store_line(row)
	return true

# Read ROM data from CSV file
func read_from_file_internal(mechanism_name: String) -> void:
	var rom_file_path = Datamanager.get_rom_file_path(mechanism_name)
	mechanism = mechanism_name

	# If file doesn't exist, initialize with defaults
	if not FileAccess.file_exists(rom_file_path):
		reset_values()
		return

	# Load CSV file
	var rom_data = Datamanager.load_csv(rom_file_path)
	if rom_data.is_empty():
		reset_values()
		return

	# Get last row of ROM data
	var last_row = rom_data[rom_data.size() - 1]
	datetime = last_row.get("DateTime", "")
	arom_min = float(last_row.get("AromMin", 0.0))
	arom_max = float(last_row.get("AromMax", 0.0))
	reaching_time = float(last_row.get("ReachingTime", 0.0))
