extends Resource
class_name HyperCubeUserData

# Date format constant
const DATE_FORMAT = "dd-MM-yyyy"
const DATETIME_FORMAT = "dd-MM-yyyy HH:mm:ss"

# User identification
var user_id: String = ""
var hospital_id: String = ""
var user_name: String = ""
var age: int = 0
var location: String = ""
var affected_limb: String = ""  # "Left" or "Right"
var date_time: String = ""

# Assessment completion status
var pinch_grasp_1_done: bool = false
var pinch_grasp_2_done: bool = false
var buttons_done: bool = false



# Session statistics
var cumulative_targets: int = 0
var cumulative_hits: int = 0
var cumulative_misses: int = 0


# Session data table (if reading from file)
var session_data_table: Array = []

func _init(hospital_no: String = "") -> void:
	if hospital_no != "":
		self.hospital_id = hospital_no
		self.user_id = hospital_no

		# Load config if it exists
		if not load_from_config(hospital_no):
			print("⚠️ Config file not found, creating new user structure...")

		# Load session data if it exists
		if not load_session_data(hospital_no):
			print("⚠️ Session file not found, initializing empty session data...")
			session_data_table.clear()

		print("✓ HyperCubeUserData initialized for: ", hospital_id)

# Load user data from config file
func load_from_config(hospital_no: String) -> bool:
	var config_path = Datamanager.get_user_path(hospital_no) + "/configdata.csv"

	if not FileAccess.file_exists(config_path):
		print("❌ Config file not found: ", config_path)
		return false

	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("❌ Failed to open config file: ", config_path)
		return false

	# Skip pre-header lines
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if line.begins_with(":"):
			continue  # Skip metadata lines
		else:
			# This is the header line, skip it
			break

	# Read user data line
	var data_line = file.get_line()
	var parts = data_line.split(",")

	if parts.size() >= 6:
		self.date_time = parts[0].strip_edges()
		self.hospital_id = parts[1].strip_edges()
		self.user_name = parts[2].strip_edges()
		self.age = int(parts[3])
		self.location = parts[4].strip_edges()
		self.affected_limb = parts[5].strip_edges()
		self.user_id = hospital_id

		# Load assessment completion status (if available)
		if parts.size() >= 9:
			self.pinch_grasp_1_done = parts[6].strip_edges().to_lower() == "true"
			self.pinch_grasp_2_done = parts[7].strip_edges().to_lower() == "true"
			self.buttons_done = parts[8].strip_edges().to_lower() == "true"

		print("✓ User data loaded: ", self.user_name)
		print("  - Pinch Grasp 1: %s" % self.pinch_grasp_1_done)
		print("  - Pinch Grasp 2: %s" % self.pinch_grasp_2_done)
		print("  - Buttons: %s" % self.buttons_done)
		return true

	return false

# Load session data from sessions file
func load_session_data(hospital_no: String) -> bool:
	var sessions_path = Datamanager.get_user_path(hospital_no) + "/sessions/sessions.csv"

	if not FileAccess.file_exists(sessions_path):
		print("⚠️ Sessions file not found: ", sessions_path)
		return false

	session_data_table.clear()
	var file = FileAccess.open(sessions_path, FileAccess.READ)
	if file == null:
		print("❌ Failed to open sessions file")
		return false

	# Skip pre-header lines and header
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if line.begins_with(":") or line.begins_with("SessionNumber"):
			continue
		else:
			break

	# Read all session rows
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if line.is_empty():
			break
		session_data_table.append(line)

	# Calculate cumulative statistics
	_calculate_cumulative_stats()

	print("✓ Session data loaded: ", session_data_table.size(), " rows")
	return true

# Calculate cumulative statistics from session data
func _calculate_cumulative_stats() -> void:
	cumulative_targets = 0
	cumulative_hits = 0
	cumulative_misses = 0

	for row_str in session_data_table:
		var parts = row_str.split(",")
		if parts.size() >= 18:
			cumulative_targets += int(parts[11])  # CurrentTargets
			cumulative_hits    += int(parts[12])  # CurrentHits
			cumulative_misses  += int(parts[13])  # CurrentMisses

# Get user's affected side
func get_affected_side() -> String:
	return affected_limb  # "Left" or "Right"

# Get success rate from cumulative data
func get_success_rate() -> float:
	if cumulative_targets == 0:
		return 0.0
	return (float(cumulative_hits) / float(cumulative_targets)) * 100.0

# Get device location (from config)
func get_device_location() -> String:
	return location



# Update trial statistics
func update_trial_stats(targets: int, hits: int, misses: int) -> void:
	cumulative_targets += targets
	cumulative_hits += hits
	cumulative_misses += misses
	print("📊 Trial stats updated - Targets: %d, Hits: %d, Misses: %d" % [targets, hits, misses])



# Get last session data (most recent trial)
func get_last_session_data() -> Dictionary:
	if session_data_table.is_empty():
		return {}

	var last_row = session_data_table[-1]
	var parts = last_row.split(",")

	# Parse last row into dictionary
	var session_dict = {
		"session_number": int(parts[0]) if parts.size() > 0 else 0,
		"datetime": parts[1] if parts.size() > 1 else "",
		"trial_number_day": int(parts[2]) if parts.size() > 2 else 0,
		"trial_number_session": int(parts[3]) if parts.size() > 3 else 0,
		"targets": int(parts[11]) if parts.size() > 11 else 0,
		"hits":    int(parts[12]) if parts.size() > 12 else 0,
		"misses":  int(parts[13]) if parts.size() > 13 else 0,
	}

	return session_dict
