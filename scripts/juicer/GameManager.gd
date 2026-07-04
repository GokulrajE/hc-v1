class_name JuicerGame
extends Node2D

# ── constants ──────────────────────────────────────────────────────────────
const FRUIT_COUNT        := 5
const FRUIT_SPACING      := 280.0
const TARGET_RADIUS      := 110.0
const GAME_DURATION      := 60.0
const HIGHLIGHT_DURATION := 7.0
const JUICE_FILL_TIME    := 3.0
const FORCE_THRESHOLD    := 5.0   # fallback; overridden from GRIP ROM
const ARROW_SPEED_KB     := 600.0

const ARROW_BASE_Y  := 50.0
const ARROW_TIP_OFF := 52.0

# Fraction of AROM range used as tolerance band at each extreme
const TRIPOD_BAND := 0.25

enum _S { WAITING, PLAYING, DONE }

# ── scene resources ────────────────────────────────────────────────────────
var _fruit_scene := preload("res://scene/juicer/fruit.tscn")
var _glass_scene := preload("res://scene/juicer/glass.tscn")

# ── nodes ──────────────────────────────────────────────────────────────────
@onready var _pour    : Node2D            = $JuicePourStream
@onready var _ui      : CanvasLayer       = $UI
@onready var _parts   : Node2D            = $ParticleManager
@onready var _bgm     : AudioStreamPlayer = $BGMPlayer
@onready var _pour_sfx: AudioStreamPlayer = $PouringSoundPlayer
@onready var _amaze   : AudioStreamPlayer = $AmazingSoundPlayer

# ── fruit / glass lists ────────────────────────────────────────────────────
var _fruits   := []
var _glasses  := []
var _fruit_xs := []

# ── game state ─────────────────────────────────────────────────────────────
var _state      := _S.WAITING
var _game_timer := 0.0
var _hl_timer   := 0.0
var _juice_prog := 0.0
var _hl_idx     := -1
var _score      := 0
var _targets    := 0
var _successes  := 0
var _failures   := 0
var _is_juicing := false
var _busy       := false

# ── arrow ──────────────────────────────────────────────────────────────────
var _arrow_x  := 960.0
var _bounce_t := 0.0

# ── device ─────────────────────────────────────────────────────────────────
var _use_device      := false
var _mech_name       := ""
var _arom_min        := 0.0
var _arom_max        := 90.0
var _arrow_l         := 0.0
var _arrow_r         := 0.0
var _force_threshold := FORCE_THRESHOLD

# ── TRIPOD-specific ────────────────────────────────────────────────────────
var _tripod_ready := true

# ── release lock (HANDLE/GRIP) ─────────────────────────────────────────────
# Arrow is frozen after each outcome until force drops below threshold.
var _waiting_release := false


# ──────────────────────────────────────────────────────────────────────────
# INIT
# ──────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_fruits()
	_setup_glasses()
	_setup_device()
	_ui.show_start()


func _setup_fruits() -> void:
	var vs := get_viewport_rect().size
	var cx := vs.x * 0.5
	var tw := FRUIT_COUNT * FRUIT_SPACING - FRUIT_SPACING * 0.5
	var sx := cx - tw * 0.5
	var fy := vs.y * 0.2

	for i in range(FRUIT_COUNT):
		var fx := sx + i * FRUIT_SPACING
		var f  := _fruit_scene.instantiate()
		f.position    = Vector2(fx, fy)
		f.fruit_index = i
		add_child(f)
		_fruits.append(f)
		_fruit_xs.append(fx)

	_arrow_l = _fruit_xs[0] - 100.0
	_arrow_r = _fruit_xs[FRUIT_COUNT - 1] + 100.0
	_arrow_x = cx


func _setup_glasses() -> void:
	var vs := get_viewport_rect().size
	var cx := vs.x * 0.5
	var tw := FRUIT_COUNT * FRUIT_SPACING - FRUIT_SPACING * 0.5
	var sx := cx - tw * 0.5
	var gy := vs.y * 0.6

	for i in range(FRUIT_COUNT):
		var g := _glass_scene.instantiate()
		g.position    = Vector2(sx + i * FRUIT_SPACING, gy)
		g.fruit_index = i
		add_child(g)
		_glasses.append(g)


func _setup_device() -> void:
	_mech_name = Appdata.selected_mechanism.name if Appdata.selected_mechanism != null else ""

	match _mech_name:
		"HANDLE", "GRIP":
			var handle_rom := ROM.new("HANDLE", true)
			if handle_rom.is_arom_set():
				_arom_min = handle_rom.arom_min
				_arom_max = handle_rom.arom_max
			var grip_rom := ROM.new("GRIP", true)
			if grip_rom.is_arom_set():
				_force_threshold = grip_rom.arom_max * 0.1
		"TRIPOD":
			if Appdata.selected_mechanism != null:
				var arom := Appdata.selected_mechanism.get_current_arom()
				_arom_min = arom[0] if arom[1] > arom[0] else 0.0
				_arom_max = arom[1] if arom[1] > arom[0] else 15.0
		_:
			pass

	if HCcomm != null and HCcomm.device_is_connected and _mech_name in ["HANDLE", "GRIP", "TRIPOD"]:
		_use_device = true


# ──────────────────────────────────────────────────────────────────────────
# MAIN LOOP
# ──────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_bounce_t += delta

	match _state:
		_S.WAITING:
			if Input.is_action_just_pressed("ui_select"):
				_begin_game()
		_S.PLAYING:
			_tick(delta)
		_S.DONE:
			pass

	queue_redraw()


func _tick(delta: float) -> void:
	if _busy:
		return

	_game_timer += delta
	_hl_timer   += delta

	_update_arrow(delta)

	# TRIPOD: update readiness based on current distance
	if _mech_name == "TRIPOD" and _use_device and HCcomm != null and HCcomm.device_is_connected:
		if not _tripod_ready:
			var dist := HCcomm.get_btw_distance()
			var ready_thresh := _arom_max - (_arom_max - _arom_min) * TRIPOD_BAND
			if dist >= ready_thresh:
				_tripod_ready = true

	if _game_timer >= GAME_DURATION:
		_end_game()
		return

	_ui.update_timer(GAME_DURATION - _game_timer)
	_ui.update_score(_score)

	if _hl_timer >= HIGHLIGHT_DURATION:
		_fruit_failure()
		return

	var on_target: bool
	if _mech_name == "TRIPOD" and _use_device:
		on_target = true  # arrow auto-aims
	else:
		on_target = _hl_idx >= 0 and abs(_arrow_x - float(_fruit_xs[_hl_idx])) <= TARGET_RADIUS

	var squeezing := _get_squeeze()

	if on_target and squeezing:
		if not _is_juicing:
			_start_juicing()

		_juice_prog = minf(_juice_prog + delta / JUICE_FILL_TIME, 1.0)
		_glasses[_hl_idx].juice_level = _juice_prog
		_fruits[_hl_idx].update_juice_extracted(_juice_prog)

		if _juice_prog >= 1.0:
			_fruit_success()
	else:
		if _is_juicing:
			_stop_juicing()


# ──────────────────────────────────────────────────────────────────────────
# ARROW
# ──────────────────────────────────────────────────────────────────────────

func _update_arrow(delta: float) -> void:
	if _mech_name == "TRIPOD" and _use_device and HCcomm != null and HCcomm.device_is_connected:
		if _hl_idx >= 0 and _hl_idx < _fruit_xs.size():
			_arrow_x = float(_fruit_xs[_hl_idx])
		return

	# HANDLE / GRIP: check release lock first
	if _waiting_release and _use_device and HCcomm != null and HCcomm.device_is_connected:
		if HCcomm.get_total_force() < _force_threshold:
			_waiting_release = false   # player released — unlock
		else:
			return   # still gripping — arrow frozen

	if _use_device and HCcomm != null and HCcomm.device_is_connected:
		var raw: float = HCcomm.angle_1
		var a_max := _arom_max if _arom_max != _arom_min else _arom_min + 1.0
		var t := clampf((raw - _arom_min) / (a_max - _arom_min), 0.0, 1.0)
		_arrow_x = lerpf(_arrow_l, _arrow_r, t)
	else:
		if Input.is_action_pressed("ui_left"):
			_arrow_x = maxf(_arrow_x - ARROW_SPEED_KB * delta, _arrow_l)
		elif Input.is_action_pressed("ui_right"):
			_arrow_x = minf(_arrow_x + ARROW_SPEED_KB * delta, _arrow_r)


func _get_squeeze() -> bool:
	if _waiting_release:
		return false   # block squeezing while arrow is locked
	if not _use_device or HCcomm == null or not HCcomm.device_is_connected:
		return Input.is_action_pressed("ui_select")
	if _mech_name == "TRIPOD":
		var dist := HCcomm.get_btw_distance()
		var squeeze_thresh := _arom_min + (_arom_max - _arom_min) * TRIPOD_BAND
		return _tripod_ready and dist <= squeeze_thresh
	return HCcomm.get_total_force() >= _force_threshold


# ──────────────────────────────────────────────────────────────────────────
# DRAW (arrow)
# ──────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _state != _S.PLAYING or _fruit_xs.is_empty():
		return

	var bounce := sin(_bounce_t * 5.0) * 8.0

	var col: Color
	if _mech_name == "TRIPOD" and _use_device:
		# Grey = must extend first; yellow = ready; green = juicing
		if _is_juicing:
			col = Color(0.05, 1.0, 0.2, 1.0)
		elif not _tripod_ready:
			col = Color(0.55, 0.55, 0.55, 0.7)
		else:
			col = Color(1.0, 0.92, 0.1, 1.0)
	else:
		if _waiting_release:
			col = Color(0.55, 0.55, 0.55, 0.65)   # grey: release grip first
		else:
			col = Color(1.0, 0.35, 0.05, 1.0)   # orange-red default
			if _hl_idx >= 0 and abs(_arrow_x - float(_fruit_xs[_hl_idx])) <= TARGET_RADIUS:
				col = Color(0.05, 1.0, 0.2, 1.0) if _is_juicing else Color(1.0, 0.95, 0.0, 1.0)

	var shadow := Color(0.0, 0.0, 0.0, 0.55)
	var ax     := _arrow_x
	var base_y := ARROW_BASE_Y
	var tip_y  := ARROW_BASE_Y + ARROW_TIP_OFF + bounce
	var off    := 3.5

	# Shadow pass
	draw_circle(Vector2(ax + off, base_y - 12.0 + off), 10.0, shadow)
	draw_line(Vector2(ax + off, base_y + off), Vector2(ax + off, tip_y - 24.0 + off), shadow, 9.0, true)
	var s_tip := Vector2(ax + off, tip_y + off)
	var s_lft := Vector2(ax - 20.0 + off, tip_y - 28.0 + off)
	var s_rgt := Vector2(ax + 20.0 + off, tip_y - 28.0 + off)
	draw_colored_polygon(PackedVector2Array([s_tip, s_lft, s_rgt]), shadow)

	# Arrow
	draw_circle(Vector2(ax, base_y - 12.0), 10.0, col)
	draw_line(Vector2(ax, base_y), Vector2(ax, tip_y - 24.0), col, 7.0, true)
	var tip := Vector2(ax, tip_y)
	var lft := Vector2(ax - 20.0, tip_y - 28.0)
	var rgt := Vector2(ax + 20.0, tip_y - 28.0)
	draw_colored_polygon(PackedVector2Array([tip, lft, rgt]), col)


# ──────────────────────────────────────────────────────────────────────────
# JUICING
# ──────────────────────────────────────────────────────────────────────────

func _start_juicing() -> void:
	_is_juicing = true
	_glasses[_hl_idx].start_juice()
	_pour.show_stream(
		_fruits[_hl_idx].global_position,
		_glasses[_hl_idx].global_position,
		_glasses[_hl_idx].get_juice_color()
	)
	if not _pour_sfx.playing:
		_pour_sfx.play()


func _stop_juicing() -> void:
	_is_juicing = false
	_pour.hide_stream()
	_pour_sfx.stop()


# ──────────────────────────────────────────────────────────────────────────
# FRUIT OUTCOMES
# ──────────────────────────────────────────────────────────────────────────

func _fruit_success() -> void:
	_busy = true
	_stop_juicing()
	_score     += 1
	_targets   += 1
	_successes += 1
	_glasses[_hl_idx].finish_juice()
	_fruits[_hl_idx].update_juice_extracted(1.0)
	_amaze.play()
	_parts.burst(_glasses[_hl_idx].global_position, _glasses[_hl_idx].get_juice_color(), 12)
	_ui.show_success_popup()
	_ui.update_score(_score)

	await get_tree().create_timer(1.0).timeout
	_glasses[_hl_idx].reset()
	_fruits[_hl_idx].reset()
	_busy = false
	_spawn_fruit()


func _fruit_failure() -> void:
	_busy = true
	_stop_juicing()
	_targets  += 1
	_failures += 1
	_ui.show_failure_popup()

	for f: Node in _fruits:
		f.deselect()

	await get_tree().create_timer(0.7).timeout
	_busy = false
	_spawn_fruit()


# ──────────────────────────────────────────────────────────────────────────
# GAME FLOW
# ──────────────────────────────────────────────────────────────────────────

func _begin_game() -> void:
	_state           = _S.PLAYING
	_game_timer      = 0.0
	_score           = 0
	_targets         = 0
	_successes       = 0
	_failures        = 0
	_hl_idx          = -1
	_tripod_ready    = true
	_waiting_release = false   # no lock for first fruit
	_ui.show_playing()
	_bgm.play()
	_spawn_fruit()


func _spawn_fruit() -> void:
	if _game_timer >= GAME_DURATION:
		_end_game()
		return

	_hl_timer   = 0.0
	_juice_prog = 0.0

	# TRIPOD: must extend before squeezing next fruit
	if _mech_name == "TRIPOD" and _use_device and _targets > 0:
		_tripod_ready = false

	# HANDLE/GRIP: freeze arrow until player releases grip
	if _mech_name in ["HANDLE", "GRIP"] and _use_device and _targets > 0:
		_waiting_release = true

	var prev := _hl_idx
	_hl_idx = randi() % FRUIT_COUNT
	while _hl_idx == prev and FRUIT_COUNT > 1:
		_hl_idx = randi() % FRUIT_COUNT

	for i in range(_fruits.size()):
		if i == _hl_idx:
			_fruits[i].highlight()
		else:
			_fruits[i].deselect()


func _end_game() -> void:
	if _state == _S.DONE:
		return
	_state  = _S.DONE
	_hl_idx = -1
	_stop_juicing()
	_bgm.stop()
	ScAudioManager.play_gameover()
	for f: Node in _fruits:
		f.deselect()
	_ui.show_game_over(_score, _targets, _successes, _failures)


# ──────────────────────────────────────────────────────────────────────────
# NAVIGATION (called by UI buttons)
# ──────────────────────────────────────────────────────────────────────────

func restart_game() -> void:
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func exit_game() -> void:
	match _state:
		_S.PLAYING:
			_end_game()
		_:
			get_tree().change_scene_to_file("res://scene/game_selection.tscn")
