class_name HyperCubeGame

extends Resource

## Game metadata
var name: String = ""
var movement: String = ""  


## Current trial statistics (reset each trial)
var current_targets: int = 0
var current_hits: int = 0  # Successes
var current_misses: int = 0  # Failures

## Cumulative statistics (persistent across trials/sessions)
var cumulative_targets: int = 0
var cumulative_hits: int = 0
var cumulative_misses: int = 0
var cumulative_stars: int = 0

## Daily statistics
var today_stars: int = 0
var current_star: int = 0

## Additional tracking
var session_number: int = 1
var trial_number_day: int = 1
var trial_number_session: int = 1

## Game speed and parameters (adaptive)
var EASY_SPEED: float = 1.0
var NORMAL_SPEED: float = 1.0
var HARD_SPEED: float = 1.0
var EXPECTED_TARGETS: int = 0
var selected_difficulty: String = "normal"
## Assessment-derived fields (populated by load_assessment_data)
var angle_min:        float = 0.0
var angle_max:        float = 110.0
var grip_threshold:   float = 10.0
var avg_reach_time:   float = 4.0
var grip_reach_time:  float = 0.0


var expected_targets:     int   = 8     # targets achievable at normal difficulty in 60 s



func _init(game_name: String = "", mechanism_name: String = "") -> void:
	name = game_name.to_upper() if game_name else "UNKNOWN"
	movement = mechanism_name.to_upper() if mechanism_name else ""
	compute_speed_mode_parameter(Appdata.selected_mechanism)




## Reset all cumulative scores (start fresh session)
func reset_cumulative_scores() -> void:
	cumulative_targets = 0
	cumulative_hits = 0
	cumulative_misses = 0
	cumulative_stars = 0
	today_stars = 0
	print("🔄 Cumulative scores reset")


## Reset current trial (prepare for next trial)
func reset_current_trial() -> void:
	current_targets = 0
	current_hits = 0
	current_misses = 0
	current_star = 0
	print("🔄 Current trial reset")

## Update trial and session numbers
func update_trial_numbers(sess_num: int, trial_day: int, trial_sess: int) -> void:
	session_number = sess_num
	trial_number_day = trial_day
	trial_number_session = trial_sess
	print("📍 Updated: Session=%d, Trial Day=%d, Trial Session=%d" % [session_number, trial_day, trial_sess])
func get_speed_for(difficulty: String) -> float:
	match difficulty.to_lower():
		"easy":   return EASY_SPEED
		"normal": return NORMAL_SPEED
		"hard":   return HARD_SPEED
		_:        return NORMAL_SPEED

func get_expected_targets_for(difficulty: String) -> int:
	var speed := get_speed_for(difficulty)
	match name:
		"TABLE WIPPING": return maxi(int(60.0 / (speed + 0.8)), 1)
		"RAIN AND RISE": return maxi(int(60.0 / (speed + 0.6)), 1)
		"JUICER":        return maxi(int(60.0 / (speed + 1.0)), 1)
		"HAT TRICK":     return maxi(int(60.0 / (speed + 0.65)), 1)
		"CATCH":         return maxi(int(60.0 / (speed + 0.65)), 1)
		"SAFE CROSSING": return maxi(int(120.0 / (3.0 * speed + 1.6)), 1)
		_:               return maxi(int(60.0 / (speed + 1.0)), 1)

func get_speed_mode_parameter(difficulty: String) -> float:
	match difficulty:
		"easy":
			set_expected_targets(EASY_SPEED)
			return EASY_SPEED
		"normal":
			set_expected_targets(NORMAL_SPEED)
			return NORMAL_SPEED
		"hard":
			set_expected_targets(HARD_SPEED)
			return HARD_SPEED
		_:
			return NORMAL_SPEED  # Default to normal if unknown
func compute_speed_mode_parameter(mechanism: HyperCubeMechanism) -> void:
	if mechanism == null:
		return
	var mech := mechanism.name.to_upper()
	var h_reach := 0.0
	var g_reach := 0.0
	if mech == "HANDLE" or mech == "GRIP":
		var h_rom := ROM.new("HANDLE", true)
		var g_rom := ROM.new("GRIP",   true)
		if h_rom.is_arom_set():
			angle_min      = h_rom.arom_min
			angle_max      = h_rom.arom_max
			h_reach        = h_rom.reaching_time
		if g_rom.is_arom_set():
			grip_threshold = g_rom.arom_max * 0.1
			g_reach        = g_rom.reaching_time
	else:
		var arom := mechanism.get_current_arom()
		if arom.size() >= 2:
			angle_min = arom[0]
			angle_max = arom[1]
		var rom = mechanism.get_current_rom()
		if rom != null:
			h_reach = rom.reaching_time

	avg_reach_time  = maxf(h_reach / 5.0, 1.0) if h_reach > 0.0 else 4.0
	grip_reach_time = g_reach / 5.0 if g_reach > 0.0 else 0.0

	# Action window = fixed time the player has to complete the action per target
	var action_window: float
	match name:
		"RAIN AND RISE": action_window = 1.0   # RAIN_TO_GROW duration
		"JUICER":        action_window = 3.0   # JUICE_FILL_TIME duration
		"HAT TRICK":     action_window = 0.0   # ball falls freely — no fixed window
		"CATCH":         action_window = 0.0   # object falls freely — no fixed window
		"SAFE CROSSING": action_window = 2.0   # braking + crossing window
		_:               action_window = 2.0   # TABLE WIPPING: wipe window

	var base_time := avg_reach_time + grip_reach_time + action_window
	EASY_SPEED   = base_time + 2.0
	NORMAL_SPEED = base_time
	HARD_SPEED   = maxf(base_time - 2.0, (1.0+action_window))
	

## set expected targets based on current game and difficulty
func set_expected_targets(speed: float) -> void:
	match name:
		"TABLE WIPPING": expected_targets = maxi(int(60.0 / (speed + 0.8)), 1)   # RESULT_DELAY 0.8
		"RAIN AND RISE": expected_targets = maxi(int(60.0 / (speed + 0.6)), 1)   # RESULT_DELAY 0.6
		"JUICER":        expected_targets = maxi(int(60.0 / (speed + 1.0)), 1)   # result+spawn ~1.0
		"HAT TRICK":     expected_targets = maxi(int(60.0 / (speed + 0.65)), 1)  # RESULT+SPAWN 0.65
		"CATCH":         expected_targets = maxi(int(60.0 / (speed + 0.65)), 1)
		"SAFE CROSSING": expected_targets = maxi(int(120.0 / (3.0 * speed + 1.6)), 1)  # 2 targets per 3-phase cycle
		_:               expected_targets = maxi(int(60.0 / (speed + 1.0)), 1)
