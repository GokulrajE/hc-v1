class_name AppData
extends Node

const COM_PORT: String = "COM15"
const BAUD_RATE: int = 115200

static var hospital_id: String = ""
static var user_name: String = ""
static var affected_limb: String = ""
static var session_number: int = 0
static var trial_number_day: int = 0
static var trial_number_session: int = 0
static var selected_movement: String = ""
static var game_name: String = ""
static var game_time: float = 30.0
static var reach_speed: float = 1.0
static var game_parameter: float = 0.0
static var cumulative_targets: int = 0
static var cumulative_hits: int = 0
static var cumulative_misses: int = 0

static func open_connection(port: String = "") -> void:
	var target_port: String = port if port != "" else COM_PORT
	if HCcomm == null:
		push_error("AppData: HCcomm not set")
		return
	HCcomm.connect_device(target_port, BAUD_RATE)

static func close_connection() -> void:
	if HCcomm == null:
		return
	HCcomm.disconnect_device()

static func load_user(id: String) -> bool:
	if DataManager == null:
		return false
	var config = DataManager.load_config(id)
	if config.is_empty():
		return false

	hospital_id = config.get("HospitalID", "")
	user_name = config.get("Name", "")
	affected_limb = config.get("AffectedLimb", "")
	session_number = 1
	trial_number_day = 1
	trial_number_session = 1
	selected_movement = ""
	game_name = ""
	cumulative_targets = 0
	cumulative_hits = 0
	cumulative_misses = 0

	return true

static func increment_session() -> void:
	session_number += 1
	trial_number_day = 1
	trial_number_session = 1
