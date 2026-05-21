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
static var game_name: String = ""
static var game_time: float = 30.0
static var reach_speed: float = 1.0
static var game_parameter: float = 0.0
static var cumulative_targets: int = 0
static var cumulative_hits: int = 0
static var cumulative_misses: int = 0
static var current_mechanism: String = ""
static var current_side: String = ""
static var mechanisms: Dictionary = {}  # Dictionary of HyperCubeMechanism objects by name

var selected_mechanism = null

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
	return true

static func increment_session() -> void:
	session_number += 1
	trial_number_day = 1
	trial_number_session = 1

func set_mechanism(mech_name: String) -> void:
	selected_mechanism = HyperCubeMechanism.new(mech_name,session_number)

# Get all mechanisms for current session
static func get_all_mechanisms() -> Array:
	return mechanisms.values()

# Clear all mechanisms (typically done when switching users)
static func clear_mechanisms() -> void:
	mechanisms.clear()
	current_mechanism = ""
	current_side = ""
	
