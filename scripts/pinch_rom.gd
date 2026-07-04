extends Node
class_name PinchROM

var pinch1_done:       bool   = false
var pinch2_done:       bool   = false
var pinch1_reach_time: float  = 0.0
var pinch2_reach_time: float  = 0.0
var pinch_datetime:    String = ""
var mechanism:         String = ""


func _init(mechanism_name: String = "", read_from_file: bool = true) -> void:
	mechanism = mechanism_name
	if read_from_file and mechanism_name != "":
		load_file()


# ── ROM interface ─────────────────────────────────────────────────────────────
func is_set() -> bool:
	return pinch_datetime != ""

func is_arom_set() -> bool:
	return is_set()

func get_current_arom() -> Array:
	return []

func set_mechanism(mech: String) -> void:
	if mechanism == "":
		mechanism = mech

func write_to_assessment_file() -> bool:
	return write_file()


# ── Setter ────────────────────────────────────────────────────────────────────
func set_pinch_data(p1_done: bool, p2_done: bool, p1_time: float, p2_time: float) -> void:
	pinch1_done       = p1_done
	pinch2_done       = p2_done
	pinch1_reach_time = p1_time
	pinch2_reach_time = p2_time
	pinch_datetime    = Datamanager.get_formatted_datetime()


# ── File I/O ──────────────────────────────────────────────────────────────────
func write_file() -> bool:
	return _write_file(
		_path(),
		"DateTime,Pinch1,Pinch2,Pinch1ReachTime,Pinch2ReachTime",
		"%s,%d,%d,%.3f,%.3f" % [pinch_datetime,
			int(pinch1_done), int(pinch2_done),
			pinch1_reach_time, pinch2_reach_time]
	)

func load_file() -> bool:
	var parts := _read_last_row(_path())
	if parts.size() < 5:
		return false
	pinch_datetime    = parts[0]
	pinch1_done       = parts[1] == "1"
	pinch2_done       = parts[2] == "1"
	pinch1_reach_time = float(parts[3])
	pinch2_reach_time = float(parts[4])
	return true


# ── Private ───────────────────────────────────────────────────────────────────
func _path() -> String:
	return Datamanager.get_user_path(Appdata.user_data.hospital_id) + "rom/pinch_rom.csv"

func _write_file(path: String, header: String, row: String) -> bool:
	var preheader := ""
	preheader += ":Location: %s\n" % Appdata.user_data.location
	preheader += ":Device: %s\n" % Appdata.device_name
	preheader += ":User: %s\n" % Appdata.user_data.hospital_id
	
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var need_header := not FileAccess.file_exists(path)
	var mode := FileAccess.WRITE if need_header else FileAccess.READ_WRITE
	var f := FileAccess.open(path, mode)
	if f == null:
		return false
	if need_header:
		f.store_line(preheader)
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
