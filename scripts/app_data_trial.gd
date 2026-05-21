extends Node

static var trial_start_time: float = 0.0
static var raw_data_buffer: String = ""
static var current_raw_filepath: String = ""
static var packet_number: int = 0

# AROM raw data logging variables
var arom_logging_active: bool = false
var arom_start_time: float = 0.0
var arom_raw_data_buffer: String = ""
var arom_raw_filepath: String = ""
var arom_packet_number: int = 0
var arom_mechanism: String = ""
var arom_knob_type: String = ""

func start_new_trial(session: int, trial: int, movement: String) -> void:
	trial_start_time = Time.get_ticks_msec() / 1000.0
	raw_data_buffer = ""
	packet_number = 0

	var filename = DataManager.get_raw_filename(session, trial, movement)
	var user_path = DataManager.get_user_path(AppData.hospital_id)
	var rawdata_dir = user_path + "rawdata/"

	if not DirAccess.dir_exists_absolute(rawdata_dir):
		DirAccess.make_dir_absolute(rawdata_dir)

	current_raw_filepath = rawdata_dir + filename
	if not DataManager.create_raw_file(current_raw_filepath):
		push_error("Failed to create raw data file: %s" % current_raw_filepath)
	HCcomm.new_device_data.connect(write_frame_data)
	
func write_frame_data() -> void:
	if current_raw_filepath == "":
		return

	packet_number += 1
	var timestamp = (Time.get_ticks_msec() / 1000.0) - trial_start_time

	var row = [
		"%.3f" % timestamp,
		packet_number,
		"%.2f" % HCcomm.force_1,
		"%.2f" % HCcomm.force_2,
		"%.2f" % HCcomm.angle_1,
		"%.2f" % HCcomm.angle_2,
		"%.2f" % HCcomm.angle_3,
		"%.2f" % HCcomm.angle_4,
		"%.2f" % HCcomm.distance_1,
		"%.2f" % HCcomm.distance_2,
		HCcomm.button_1,
		HCcomm.button_2,
		HCcomm.button_3,
		HCcomm.button_4,
		HCcomm.button_5,
		HCcomm.button_6,
		HCcomm.button_7
	]

	raw_data_buffer += ",".join(row.map(func(x): return str(x))) + "\n"

func flush_raw_data() -> void:
	if current_raw_filepath == "" or raw_data_buffer == "":
		return

	var file = FileAccess.open(current_raw_filepath, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_buffer(raw_data_buffer.to_utf8_buffer())

func stop_trial(n_targets: int, n_success: int, n_failure: int) -> void:
	HCcomm.new_device_data.disconnect(write_frame_data)
	flush_raw_data()

	var trial_duration = (Time.get_ticks_msec() / 1000.0) - trial_start_time
	var success_rate = 0.0
	if n_targets > 0:
		success_rate = float(n_success) / float(n_targets) * 100.0

	var trial_time = trial_duration
	AppData.cumulative_targets += n_targets
	AppData.cumulative_hits += n_success
	AppData.cumulative_misses += n_failure

	var raw_filename = DataManager.get_raw_filename(AppData.session_number, AppData.trial_number_session, AppData.current_mechanism)

	var session_row = [
		AppData.session_number,
		DataManager.get_formatted_datetime(),
		AppData.trial_number_day,
		AppData.trial_number_session,
		"%.2f" % trial_start_time,
		"%.2f" % (trial_start_time + trial_duration),
		AppData.current_mechanism,
		AppData.game_name,
		"%.2f" % AppData.reach_speed,
		"%.2f" % AppData.game_parameter,
		"%.2f" % trial_duration,
		"%.1f" % success_rate,
		"%.2f" % trial_time,
		n_targets,
		n_success,
		n_failure,
		AppData.cumulative_targets,
		AppData.cumulative_hits,
		AppData.cumulative_misses,
		raw_filename
	]

	DataManager.append_session_row(AppData.hospital_id, session_row)

	current_raw_filepath = ""
	raw_data_buffer = ""
	packet_number = 0

# Start AROM raw data logging
func start_arom_raw_data_logging() -> void:
	arom_logging_active = true
	arom_start_time = Time.get_ticks_msec() / 1000.0
	arom_raw_data_buffer = ""
	arom_packet_number = 0
	arom_mechanism = Appdata.selected_mechanism.name


	# Create filename: arom-{mechanism}-{datetime}.csv
	var datetime = DataManager.get_formatted_datetime().replace(" ", "_").replace(":", "-")
	var filename = "arom-%s-%s.csv" % [
		arom_mechanism.to_lower().replace(" ", "_"),
		datetime
	]

	var user_path = DataManager.get_user_path(AppData.hospital_id)
	var rawdata_dir = user_path + "rawdata/"

	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(rawdata_dir):
		DirAccess.make_dir_absolute(rawdata_dir)

	arom_raw_filepath = rawdata_dir + filename

	# Create file with headers
	var preheader = ""
	preheader += ":Device: HC-V1\n"
	preheader += ":Location: %s\n" % AppData.hospital_id
	preheader += ":User: %s\n" % AppData.hospital_id
	preheader += ":Mechanism: %s\n" % arom_mechanism
	preheader += ",".join(DataManager.RAW_HEADER) + "\n"

	var file = FileAccess.open(arom_raw_filepath, FileAccess.WRITE)
	if file:
		file.store_string(preheader)
	else:
		push_error("Failed to create AROM raw data file: %s" % arom_raw_filepath)
		arom_logging_active = false
		return

	# Connect to device data signal
	if HCcomm:
		HCcomm.new_device_data.connect(_on_arom_device_data_received)
	print("AROM raw data logging started: %s" % arom_raw_filepath)

# Handle new device data during AROM logging
func _on_arom_device_data_received() -> void:
	if not arom_logging_active or arom_raw_filepath == "":
		return

	arom_packet_number += 1
	var timestamp = (Time.get_ticks_msec() / 1000.0) - arom_start_time

	var row = [
		"%.3f" % timestamp,
		arom_packet_number,
		"%.2f" % HCcomm.force_1,
		"%.2f" % HCcomm.force_2,
		"%.2f" % HCcomm.angle_1,
		"%.2f" % HCcomm.angle_2,
		"%.2f" % HCcomm.angle_3,
		"%.2f" % HCcomm.angle_4,
		"%.2f" % HCcomm.distance_1,
		"%.2f" % HCcomm.distance_2,
		HCcomm.button_1,
		HCcomm.button_2,
		HCcomm.button_3,
		HCcomm.button_4,
		HCcomm.button_5,
		HCcomm.button_6,
		HCcomm.button_7
	]

	arom_raw_data_buffer += ",".join(row.map(func(x): return str(x))) + "\n"

# Stop AROM raw data logging and write to file
func stop_arom_raw_data_logging() -> void:
	if not arom_logging_active:
		return

	arom_logging_active = false

	# Disconnect from device data signal
	if HCcomm:
		HCcomm.new_device_data.disconnect(_on_arom_device_data_received)

	# Write buffered data to file
	if arom_raw_filepath != "" and arom_raw_data_buffer != "":
		var file = FileAccess.open(arom_raw_filepath, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
			file.store_buffer(arom_raw_data_buffer.to_utf8_buffer())
			print("AROM raw data saved: %s (%d packets)" % [arom_raw_filepath, arom_packet_number])
		else:
			push_error("Failed to write AROM raw data to file: %s" % arom_raw_filepath)

	# Clear variables
	arom_raw_data_buffer = ""
	arom_raw_filepath = ""
	arom_packet_number = 0
	arom_mechanism = ""
	arom_knob_type = ""
