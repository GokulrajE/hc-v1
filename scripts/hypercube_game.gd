class_name HyperCubeGame

extends Resource

## Game metadata
var name: String = ""
var movement: String = ""  
## Game parameters
var reach_speed: float = 1.0 
var game_speed: float = 0.0 
var game_parameter: float = 0.0  
var game_duration: float = 60.0  

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


func _init(game_name: String = "", mechanism_name: String = "", reach_spd: float = 1.0) -> void:
	name = game_name.to_upper() if game_name else "UNKNOWN"
	movement = mechanism_name.to_upper() if mechanism_name else ""
	reach_speed = clamp(reach_spd, 0.5, 2.0)
	game_duration = 60.0
	_calculate_game_speed()


## Calculate game speed based on reach speed
func _calculate_game_speed() -> void:
	# Scale game speed: reach_speed 1.0 = base speed 100
	game_speed = reach_speed * 100.0
	print("✓ Game speed calculated: %.0f (reach speed: %.2f)" % [game_speed, reach_speed])


## Update reach speed and recalculate game speed
func set_reach_speed(spd: float) -> void:
	reach_speed = clamp(spd, 0.5, 2.0)
	_calculate_game_speed()
	print("✓ Reach speed for '%s' set to %.2f | Game speed: %.0f" % [name, reach_speed, game_speed])


## Set game-specific parameter (e.g., reach duration, difficulty level)
func set_game_parameter(param: float) -> void:
	game_parameter = param
	print("✓ Game parameter set to %.2f" % game_parameter)



## Update current trial statistics
func update_targets_hits_misses(targets: int, hits: int, misses: int) -> void:
	current_targets = targets
	current_hits = hits
	current_misses = misses

	# Add to cumulative
	cumulative_targets += targets
	cumulative_hits += hits
	cumulative_misses += misses

	print("📊 Trial Stats: Targets=%d, Hits=%d, Misses=%d" % [targets, hits, misses])
	print("📈 Cumulative: Targets=%d, Hits=%d, Misses=%d" % [cumulative_targets, cumulative_hits, cumulative_misses])


## Get success rate for current trial
func get_current_success_rate() -> float:
	if current_targets == 0:
		return 0.0
	return (current_hits / float(current_targets)) * 100.0


## Get success rate for all trials (cumulative)
func get_cumulative_success_rate() -> float:
	if cumulative_targets == 0:
		return 0.0
	return (cumulative_hits / float(cumulative_targets)) * 100.0


## Award star for achievement
func award_star() -> void:
	cumulative_stars += 1
	current_star = 1
	today_stars += 1
	print("⭐ Star awarded! Total: %d | Today: %d" % [cumulative_stars, today_stars])


## Reset current trial star count
func reset_trial_star() -> void:
	current_star = 0


## Check if achievement unlocked today
func is_achieved_today() -> bool:
	return today_stars > 0


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
