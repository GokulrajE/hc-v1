class_name HTGame
extends Node2D

# ============================================================
# CONSTANTS
# ============================================================
const PLAY_LEFT:  float = 150.0
const PLAY_RIGHT: float = 1770.0

const HAT_Y:      float = 860.0
const HAT_SPEED:  float = 700.0
const HAT_HALF_W: float = 120.0

const BALL_SPEED:  float = 380.0
const BALL_RADIUS: float = 45.0

const SPAWN_DELAY:   float = 0.05   # small gap after spawning before MOVE starts
const RESULT_DELAY:  float = 0.6    # pause after catch/miss before next ball

const GAME_DURATION: float = 60.0

const BALL_SCALE: float = 0.7

# ============================================================
# NODES
# ============================================================
@onready var hat_sprite: Sprite2D = $HatSprite
@onready var ui                   = $HTUI

# ============================================================
# GAME STATE MACHINE  (mirrors Unity HatGameController)
# ============================================================
enum GameState { WAITING, START, SPAWNBALL, MOVE, SUCCESS, FAILURE, STOP, DONE }
var _game_state: GameState = GameState.WAITING

# Event flags (set inside MOVE, read inside SUCCESS/FAILURE)
var _is_ball_caught:  bool  = false
var _is_ball_missed:  bool  = false
var _is_game_started: bool  = false
var _event_delay_timer: float = 0.0
var _run_once: bool = false

# Score / trial counters
var score:     int = 0
var n_targets: int = 0
var n_success: int = 0
var n_failure: int = 0
var time_left: float = GAME_DURATION

# Hat
var hat_x: float = 960.0

# Current single falling object (one ball at a time)
var _ball_sprite: Sprite2D = null

var _ball_tex: Texture2D = null


# ============================================================
# READY
# ============================================================
func _ready() -> void:
	_ball_tex = load("res://assets/hattrick/BowlingBallSprite.png")
	hat_sprite.position = Vector2(960.0, HAT_Y)
	hat_sprite.visible  = false
	ui.show_start()


# ============================================================
# INPUT  (WAITING → START)
# ============================================================
func _process(_delta: float) -> void:
	if _game_state == GameState.WAITING:
		if Input.is_action_just_pressed("ui_select"):
			_is_game_started = true


# ============================================================
# PHYSICS — hat + state machine
# ============================================================
func _physics_process(delta: float) -> void:
	# Hat movement active during MOVE / SUCCESS / FAILURE
	match _game_state:
		GameState.MOVE, GameState.SUCCESS, GameState.FAILURE:
			_update_hat(delta)

	_run_game_state_machine(delta)


func _update_hat(delta: float) -> void:
	if HCcomm.device_is_connected and Appdata.selected_mechanism != null:
		var arom := Appdata.selected_mechanism.get_current_arom()
		var a_min: float = arom[0]
		var a_max: float = arom[1] if arom[1] != arom[0] else arom[0] + 1.0
		hat_x = remap(_get_knob_angle(), a_min, a_max,
				PLAY_LEFT + HAT_HALF_W, PLAY_RIGHT - HAT_HALF_W)
	else:
		if Input.is_action_pressed("ui_left"):
			hat_x -= HAT_SPEED * delta
		if Input.is_action_pressed("ui_right"):
			hat_x += HAT_SPEED * delta
	hat_x = clamp(hat_x, PLAY_LEFT + HAT_HALF_W, PLAY_RIGHT - HAT_HALF_W)
	hat_sprite.position.x = hat_x


func _get_knob_angle() -> float:
	if Appdata.selected_mechanism == null:
		return 0.0
	match Appdata.selected_mechanism.name:
		"KNOB":      return HCcomm.angle_2
		"FINE KNOB": return HCcomm.angle_4
		"KEY KNOB":  return HCcomm.angle_3
		"TRIPOD":    return HCcomm.get_avg_btw_distance()
		_:           return HCcomm.angle_2


# ============================================================
# RUN GAME STATE MACHINE
# ============================================================
func _run_game_state_machine(delta: float) -> void:
	# Tick timer for all active play states
	var is_time_up := false
	if _game_state not in [GameState.WAITING, GameState.STOP, GameState.DONE]:
		time_left = maxf(time_left - delta, 0.0)
		ui.update_timer(time_left)
		is_time_up = time_left <= 0.0

	match _game_state:

		GameState.WAITING:
			if _is_game_started:
				_game_state = GameState.START

		GameState.START:
			_initialize_game()
			_game_state = GameState.SPAWNBALL

		GameState.SPAWNBALL:
			if _event_delay_timer <= 0.0 and not _run_once:
				_spawn_ball()
				_event_delay_timer = SPAWN_DELAY
				_run_once = true
			else:
				_event_delay_timer -= delta
				if _event_delay_timer <= 0.0:
					_game_state = GameState.MOVE

		GameState.MOVE:
			if is_instance_valid(_ball_sprite):
				_ball_sprite.position.y += BALL_SPEED * delta
				var ball_y := _ball_sprite.position.y

				if ball_y >= HAT_Y - 80.0:
					# Reached hat level — check overlap
					var dx: float = absf(_ball_sprite.position.x - hat_x)
					if dx <= HAT_HALF_W + BALL_RADIUS:
						_is_ball_caught = true
					else:
						_is_ball_missed = true
				elif ball_y > 1150.0:
					# Fell off screen
					_is_ball_missed = true
			else:
				_is_ball_missed = true

			if _is_ball_caught:
				_on_catch()
				_event_delay_timer = RESULT_DELAY
				_game_state = GameState.SUCCESS
			elif _is_ball_missed:
				_on_miss()
				_event_delay_timer = RESULT_DELAY
				_game_state = GameState.FAILURE

		GameState.SUCCESS, GameState.FAILURE:
			_event_delay_timer -= delta
			if _event_delay_timer <= 0.0:
				_is_ball_caught  = false
				_is_ball_missed  = false
				_run_once        = false
				_game_state = GameState.STOP if is_time_up else GameState.SPAWNBALL

		GameState.STOP:
			_end_game()
			_game_state = GameState.DONE

		GameState.DONE:
			pass   # restart / menu buttons handle navigation


# ============================================================
# GAME LIFECYCLE
# ============================================================
func _initialize_game() -> void:
	score     = 0
	n_targets = 0
	n_success = 0
	n_failure = 0
	time_left = GAME_DURATION
	hat_x     = 960.0
	hat_sprite.position.x = hat_x
	hat_sprite.visible    = true
	_is_ball_caught  = false
	_is_ball_missed  = false
	_run_once        = false
	_event_delay_timer = 0.0

	ui.update_score(0)
	ui.update_timer(GAME_DURATION)
	ui.show_playing()

	# AppDataTrial.start_new_trial()
	ScAudioManager.play_background_music("res://assets/audio/hattrick_bg.mp3")
	print("🎩 HatTrick started — 60s trial")


func _end_game() -> void:
	_free_ball()
	hat_sprite.visible = false

	# AppDataTrial.stop_trial(n_targets, n_success, n_failure)
	ScAudioManager.stop_music()
	ScAudioManager.play_gameover()
	ui.show_game_over(score, n_targets, n_success, n_failure)
	print("🏁 HatTrick Over | Score:%d | %d/%d caught" % [score, n_success, n_targets])


# ============================================================
# BALL MANAGEMENT
# ============================================================
func _spawn_ball() -> void:
	_free_ball()

	if _ball_tex == null:
		return

	n_targets += 1

	_ball_sprite          = Sprite2D.new()
	_ball_sprite.texture  = _ball_tex
	_ball_sprite.scale    = Vector2(BALL_SCALE, BALL_SCALE)
	_ball_sprite.position = Vector2(
		randf_range(PLAY_LEFT + 60.0, PLAY_RIGHT - 60.0), -60.0
	)
	_ball_sprite.z_index  = 10
	add_child(_ball_sprite)


func _free_ball() -> void:
	if is_instance_valid(_ball_sprite):
		_ball_sprite.queue_free()
	_ball_sprite = null


# ============================================================
# CATCH / MISS
# ============================================================
func _on_catch() -> void:
	_free_ball()
	score     += 1
	n_success += 1
	ui.update_score(score)
	ui.show_success_popup()
	ScAudioManager.play_cg_success()
	_animate_hat_catch()
	print("🎉 Caught! Score: %d" % score)


func _on_miss() -> void:
	_free_ball()
	n_failure += 1
	ui.show_failure_popup()
	ScAudioManager.play_cg_miss()


func _animate_hat_catch() -> void:
	var tw := create_tween()
	tw.tween_property(hat_sprite, "position:y", HAT_Y - 25.0, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(hat_sprite, "position:y", HAT_Y,        0.12).set_ease(Tween.EASE_IN)


# ============================================================
# NAVIGATION
# ============================================================
func restart_game() -> void:
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func exit_game() -> void:
	if _game_state not in [GameState.WAITING, GameState.DONE]:
		_game_state = GameState.STOP
