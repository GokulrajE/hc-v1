class_name AppData
extends Node


const COM_PORT: String = "COM15"
const BAUD_RATE: int = 115200
const device_name: String = "HyperCube"
var current_session_number: int 
var start_time:String
var trial_start_time:float
var trail_stop_time:float

var user_data: HyperCubeUserData
var selected_mechanism : HyperCubeMechanism
 
func initilize_user(hospital_id: String) -> void:
	# Initialize user data
	start_time = Datamanager.get_formatted_datetime()
	user_data = HyperCubeUserData.new(hospital_id)
	selected_mechanism = null

	# Update current session number - get last session number from history and increment it
	if user_data.session_data_table.size() > 0:
		# Get the last row from session data table
		var last_row = user_data.session_data_table[-1]
		var parts = last_row.split(",")
		# SessionNumber is in parts[0] (first column)
		var last_session_number = int(parts[0]) if parts.size() > 0 else 0
		current_session_number = last_session_number + 1
	else:
		# No sessions exist, start with session 1
		current_session_number = 1

	
	print("✓ Current session number set to: %d" % current_session_number)

func initialize_connection(port: String = "") -> void:
	var target_port: String = port if port != "" else COM_PORT
	if HCcomm == null:
		push_error("AppData: HCcomm not set")
		return
	HCcomm.connect_device(target_port, BAUD_RATE)

static func close_connection() -> void:
	if HCcomm == null:
		return
	HCcomm.disconnect_device()



func set_mechanism(mech_name: String,) -> void:
	selected_mechanism = HyperCubeMechanism.new(mech_name,current_session_number)



	
