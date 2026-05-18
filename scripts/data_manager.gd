extends Node

const CONFIG_HEADER = ["HospitalID", "Name", "Age", "Location", "AffectedLimb", "DevicePort", "CreatedDate"]
const SESSION_HEADER = ["SessionNumber", "DateTime", "TrialNumberDay", "TrialNumberSession", "TrialStartTime", "TrialStopTime", "Movement", "GameName", "ReachSpeed", "GameParameter", "GameDuration", "SuccessRate", "MoveTime", "CurrentTargets", "CurrentHits", "CurrentMisses", "CumulativeTargets", "CumulativeHits", "CumulativeMisses", "RawDataFileName"]
const RAW_HEADER = ["Timestamp", "PacketNumber", "Force1", "Force2", "Angle1", "Angle2", "Angle3", "Angle4", "Distance1", "Distance2", "Button1", "Button2", "Button3", "Button4", "Button5", "Button6", "Button7"]

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
	file.store_line(":Device: HC-V1")
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

func get_raw_filename(session: int, trial: int, movement: String) -> String:
	return "raw-s%02d-t%03d-%s.csv" % [session, trial, movement.to_lower()]

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
