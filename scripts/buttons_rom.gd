extends Node
class_name ButtonsROM

var buttons_done:       bool   = false
var buttons_reach_time: float  = 0.0
var buttons_datetime:   String = ""
var mechanism:          String = ""


func _init(mechanism_name: String = "", read_from_file: bool = true) -> void:
	mechanism = mechanism_name
	if read_from_file and mechanism_name != "":
		load_file()


# ── ROM interface ─────────────────────────────────────────────────────────────
func is_set() -> bool:
	return buttons_datetime != ""

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
func set_buttons_data(done: bool, time: float) -> void:
	buttons_done       = done
	buttons_reach_time = time
	buttons_datetime   = Datamanager.get_formatted_datetime()


# ── File I/O ──────────────────────────────────────────────────────────────────
func write_file() -> bool:
	return _write_file(
		_path(),
		"DateTime,Buttons,ButtonsReachTime",
		"%s,%d,%.3f" % [buttons_datetime, int(buttons_done), buttons_reach_time]
	)

func load_file() -> bool:
	var parts := _read_last_row(_path())
	if parts.size() < 3:
		return false
	buttons_datetime   = parts[0]
	buttons_done       = parts[1] == "1"
	buttons_reach_time = float(parts[2])
	return true


# ── Private ───────────────────────────────────────────────────────────────────
func _path() -> String:
	return Datamanager.get_user_path(Appdata.user_data.hospital_id) + "rom/buttons_rom.csv"

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
