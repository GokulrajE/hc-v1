
extends Resource
class_name HyperCubeMechanism




# Default speeds for each mechanism (Hz)
const DEFAULT_SPEEDS = {
	"Hand Grip": 10.0,
	"Knobs": 10.0,
	"Tripod Grip": 10.0,

}

# Mechanism properties
var name: String = ""
var side: String = ""  # "Left" or "Right"
var arom_completed: bool = false  # HyperCube only has AROM
var old_rom
var new_rom
var curr_speed: float = -1.0
var trial_number_day: int = 0
var trial_number_session: int = 0

func _init(mechanism_name: String = "", sess_no: int = 1) -> void:
	name = mechanism_name.to_upper() if mechanism_name else ""

	# Initialize ROM objects
	old_rom = ROM.new(name, true)  # Read from file if exists (previous assessment)
	new_rom = ROM.new("", false)  # Empty ROM for new measurements

	# Reset flags
	arom_completed = false

	curr_speed = -1.0
	update_trial_numbers(sess_no)

# Check if this mechanism matches the given name
func is_mechanism(mech_name: String) -> bool:
	return name.to_upper() == mech_name.to_upper()

# Check if this mechanism is on the given side
func is_side(side_name: String) -> bool:
	return side.to_upper() == side_name.to_upper()

# Check if speed has been updated
func is_speed_updated() -> bool:
	return curr_speed > 0.0

# Move to next trial
func next_trial() -> void:
	trial_number_day += 1
	trial_number_session += 1

# Get current ROM (prefers newRom if set, falls back to oldRom)
func get_current_rom():
	if new_rom != null and new_rom.is_set():
		return new_rom
	elif old_rom != null and old_rom.is_set():
		return old_rom
	return null

# Get current AROM values (HyperCube only)
func get_current_arom() -> Array:
	var rom = get_current_rom()
	return rom.get_current_arom() if rom else []

# Reset AROM values
func reset_arom_values() -> void:
	if new_rom != null:
		new_rom.set_arom(0.0, 0.0)
	arom_completed = false

# Set new AROM values (HyperCube only) with optional reaching time
func set_new_arom_values(amin: float, amax: float, reach_time: float = 0.0) -> void:
	if new_rom == null:
		push_error("HyperCubeMechanism: new_rom not initialized")
		return

	new_rom.set_arom(amin, amax, reach_time)
	if amin != 0.0 or amax != 0.0:
		arom_completed = true

	# Set mechanism if not already set
	if new_rom.mechanism == "":
		new_rom.set_mechanism(name)

# Save assessment data (ROM values) when AROM assessment completed
func save_assessment_data() -> bool:
	if arom_completed and new_rom != null:
		return new_rom.write_to_assessment_file()
	return false

# Update trial numbers from session history
func update_trial_numbers(session_no: int) -> void:
	trial_number_day = 0
	trial_number_session = session_no

	# TODO: Load from CSV session file when available
	# For now, initialize to 0 and increment on first trial

# Get mechanism speed (default or custom)
func get_speed() -> float:
	if is_speed_updated():
		return curr_speed
	return DEFAULT_SPEEDS.get(name, 10.0)

# Set custom mechanism speed
func set_speed(speed: float) -> void:
	curr_speed = speed if speed > 0.0 else -1.0

# Get mechanism info as string
func _to_string() -> String:
	var arom_status = "COMPLETED" if arom_completed else "PENDING"
	return "HyperCubeMechanism(%s, %s) - AROM:%s" % [
		name,
		side,
		arom_status
	]
