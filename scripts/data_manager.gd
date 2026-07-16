extends Node
class_name DataStructure

const CONFIG_HEADER = ["DateTime", "HospitalID", "Name", "Age", "Location", "AffectedLimb","PinchGrasp1", "PinchGrasp2", "Buttons"]
const SESSION_HEADER = ["SessionNumber", "DateTime", "TrialNumberDay", "TrialNumberSession", "TrialStartTime", "TrialStopTime", "Mechanism", "GameName", "GameParameter", "GameDuration", "SuccessRate", "CurrentTargets", "CurrentHits", "CurrentMisses", "CumulativeTargets", "CumulativeHits", "CumulativeMisses", "RawDataFileName", "ExpectedTarget"]
const RAW_HEADER = ["Force1", "Force2", "Angle1", "Angle2", "Angle3", "Angle4", "Distance1", "Distance2", "Button1", "Button2", "Button3", "Button4", "Button5", "Button6", "Button7", "GameState", "PlayerX", "PlayerY", "TargetX", "TargetY"]

func get_formatted_datetime() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%02d-%02d-%04d %02d:%02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute, dt.second]

func get_data_root() -> String:
	if OS.is_debug_build():
		return ProjectSettings.globalize_path("res://data/")
	else:
		return OS.get_executable_path().get_basename() + "_data/"

func get_user_path(hospital_id: String) -> String:
	return get_data_root() + hospital_id + "/"

func user_exists(hospital_id: String) -> bool:
	var config_path = get_user_path(hospital_id) + "configdata.csv"
	return FileAccess.file_exists(config_path)
	

func create_file_structure(hospital_id: String) -> bool:
	var base_path = get_user_path(hospital_id)
	var dirs = ["sessions", "rawdata", "rom", "applog", "errorlog"]

	for dir_name in dirs:
		var dir_path = base_path + dir_name
		var error = DirAccess.make_dir_recursive_absolute(dir_path)
		if error != OK:
			push_error("Failed to create directory: %s" % dir_path)
			return false
	return true

func create_session_file(hospital_id: String) -> bool:
	var user_path = get_user_path(hospital_id)
	var sessions_dir = user_path + "sessions/"

	if not DirAccess.dir_exists_absolute(sessions_dir):
		var error = DirAccess.make_dir_absolute(sessions_dir)
		if error != OK:
			push_error("Failed to create sessions directory: %s" % sessions_dir)
			return false

	var filepath = sessions_dir + "sessions.csv"
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("Failed to create sessions file: %s" % filepath)
		return false

	file.store_csv_line(SESSION_HEADER)
	return true

func save_config(data: Dictionary) -> bool:
	var hospital_id = data.get("HospitalID", "")
	if hospital_id == "":
		return false

	var user_path = get_user_path(hospital_id)
	if not DirAccess.dir_exists_absolute(user_path):
		var error = DirAccess.make_dir_absolute(user_path)
		if error != OK:
			push_error("Failed to create user directory: %s" % user_path)
			return false

	var filepath = user_path + "configdata.csv"
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("Failed to create config file: %s" % filepath)
		return false

	file.store_line(":Location: %s" % data.get("Location", ""))
	file.store_line(":Device: %s" % Appdata.device_name)
	file.store_line(":User: %s" % hospital_id)

	file.store_csv_line(CONFIG_HEADER)

	var row = []
	for header in CONFIG_HEADER:
		row.append(str(data.get(header, "")))
	file.store_csv_line(row)

	return true

func load_config(hospital_id: String) -> Dictionary:
	var filepath = get_user_path(hospital_id) + "configdata.csv"
	var config_data = {}

	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		return config_data

	var line_num = 0
	while not file.eof_reached():
		var line = file.get_line()
		if line == "":
			continue

		if line.begins_with(":"):
			continue

		if line_num == 0:
			line_num += 1
			continue

		var values = line.split(",")
		if values.size() == CONFIG_HEADER.size():
			for i in range(CONFIG_HEADER.size()):
				config_data[CONFIG_HEADER[i]] = values[i]
			break
		line_num += 1

	return config_data

func get_raw_filename(session: int, trial: int, movement: String, game: String) -> String:
	return "raw-s%02d-t%03d-%s-%s-%s.csv" % [session, trial, game.to_lower(), movement.to_lower()]

func get_rom_file_path(mechanism: String) -> String:
	if Appdata.user_data.hospital_id == "":
		push_error("DataManager: hospital_id not set in AppData")
		return ""
	var rom_dir = get_user_path(Appdata.user_data.hospital_id) + "rom/"
	return rom_dir + mechanism.to_lower().replace(" ", "_") + "_rom.csv"

func append_session_row(hospital_id: String, row: Array) -> bool:
	var filepath = get_user_path(hospital_id) + "sessions/sessions.csv"
	var file = FileAccess.open(filepath, FileAccess.READ_WRITE)
	if not file:
		return false

	file.seek_end()
	file.store_csv_line(row)
	return true

func create_raw_file(filepath: String) -> bool:
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		return false
	file.store_csv_line(RAW_HEADER)
	return true

func append_raw_row(filepath: String, row: Array) -> bool:
	var file = FileAccess.open(filepath, FileAccess.READ_WRITE)
	if not file:
		return false

	file.seek_end()
	var csv_row = []
	for val in row:
		csv_row.append(str(val))
	file.store_csv_line(csv_row)
	return true

func load_csv(filepath: String) -> Array:
	var data = []
	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		return data

	var headers = []
	var line_num = 0
	while not file.eof_reached():
		var line = file.get_line()
		if line == "":
			continue

		if line.begins_with(":"):
			continue

		if line_num == 0:
			headers = line.split(",")
			line_num += 1
			continue

		var values = line.split(",")
		var row_dict = {}
		for i in range(headers.size()):
			if i < values.size():
				row_dict[headers[i]] = values[i]
		data.append(row_dict)
		line_num += 1

	return data


## Returns {normal_count, avg_achievement, unlocked} for the given mechanism.
## unlocked = True when the user has completed 3+ normal trials with avg SuccessRate >= 50%.
func get_mechanism_training_status(hospital_id: String, mechanism_name: String) -> Dictionary:
	var path := get_user_path(hospital_id) + "sessions/sessions.csv"
	var rows  := load_csv(path)
	var normal_count := 0
	var total_rate   := 0.0
	for row: Dictionary in rows:
		if row.get("Mechanism", "") == mechanism_name and row.get("GameParameter", "").begins_with("N|"):
			normal_count += 1
			total_rate   += float(row.get("SuccessRate", "0"))
	var avg := (total_rate / float(normal_count)) if normal_count > 0 else 0.0
	return {
		"normal_count": normal_count,
		"avg_achievement": avg,
		"unlocked": normal_count >= 3 and avg >= 50.0
	}
