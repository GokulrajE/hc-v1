extends Node
class_name PinchButtonsROM

var pinch1_done:       bool  = false
var pinch2_done:       bool  = false
var pinch1_reach_time: float = 0.0
var pinch2_reach_time: float = 0.0
var pinch_datetime:    String = ""

var buttons_done:       bool  = false
var buttons_reach_time: float = 0.0
var buttons_datetime:   String = ""

var mechanism: String = ""

func _init(mechanism_name: String = "", read_from_file: bool = true) -> void:
	mechanism = mechanism_name
	if read_from_file and mechanism_name != "":
		load_pinch_file()
		load_buttons_file()


# ── ROM-compatible interface ───────────────────────────────────────────────────
func is_set() -> bool:
	return is_pinch_assessed() and is_buttons_assessed()

func is_arom_set() -> bool:
	return is_set()

func get_current_arom() -> Array:
	return []

func set_mechanism(mech: String) -> void:
	if mechanism == "":
		mechanism = mech

func write_to_assessment_file() -> bool:
	var a := write_pinch_file()
	var b := write_buttons_file()
	return a and b


# ── Setters ───────────────────────────────────────────────────────────────────
func set_pinch_data(p1_done: bool, p2_done: bool, p1_time: float, p2_time: float) -> void:
	pinch1_done       = p1_done
	pinch2_done       = p2_done
	pinch1_reach_time = p1_time
	pinch2_reach_time = p2_time
	pinch_datetime    = Datamanager.get_formatted_datetime()

func set_buttons_data(done: bool, time: float) -> void:
	buttons_done       = done
	buttons_reach_time = time
	buttons_datetime   = Datamanager.get_formatted_datetime()


# ── Status helpers ────────────────────────────────────────────────────────────
func is_pinch_assessed() -> bool:
	return pinch_datetime != ""

func is_buttons_assessed() -> bool:
	return buttons_datetime != ""

func is_fully_assessed() -> bool:
	return is_set()


# ── File I/O ──────────────────────────────────────────────────────────────────
func write_pinch_file() -> bool:
	return _write_file(
		_pinch_path(),
		"DateTime,Pinch1,Pinch2,Pinch1ReachTime,Pinch2ReachTime",
		"%s,%d,%d,%.3f,%.3f" % [
			pinch_datetime,
			int(pinch1_done), int(pinch2_done),
			pinch1_reach_time, pinch2_reach_time
		]
	)

func write_buttons_file() -> bool:
	return _write_file(
		_buttons_path(),
		"DateTime,Buttons,ButtonsReachTime",
		"%s,%d,%.3f" % [buttons_datetime, int(buttons_done), buttons_reach_time]
	)

func load_pinch_file() -> bool:
	var parts := _read_last_row(_pinch_path())
	if parts.size() < 5:
		return false
	pinch_datetime    = parts[0]
	pinch1_done       = parts[1] == "1"
	pinch2_done       = parts[2] == "1"
	pinch1_reach_time = float(parts[3])
	pinch2_reach_time = float(parts[4])
	return true

func load_buttons_file() -> bool:
	var parts := _read_last_row(_buttons_path())
	if parts.size() < 3:
		return false
	buttons_datetime   = parts[0]
	buttons_done       = parts[1] == "1"
	buttons_reach_time = float(parts[2])
	return true


# ── Private ───────────────────────────────────────────────────────────────────
func _pinch_path() -> String:
	return Datamanager.get_user_path(Appdata.user_data.hospital_id) + "rom/pinch_rom.csv"

func _buttons_path() -> String:
	return Datamanager.get_user_path(Appdata.user_data.hospital_id) + "rom/buttons_rom.csv"

func _write_file(path: String, header: String, row: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var need_header := not FileAccess.file_exists(path)
	var mode := FileAccess.WRITE if need_header else FileAccess.READ_WRITE
	var f := FileAccess.open(path, mode)
	if f == null:
		return false
	if need_header:
		f.store_line(":Device: HC-V1")
		f.store_line(header)
	else:
		f.seek_end(0)
	f.store_line(row)
	return true

func _read_last_row(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var last := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "" and not line.begins_with(":") and not line.begins_with("Date"):
			last = line
	return last.split(",") if last != "" else []
