class_name TWGame
extends Node2D



# ============================================================
# NODES
# ============================================================
@onready var cloth:            Sprite2D      = $cloth
@onready var cleaner:          Sprite2D      = $cleaner
@onready var nozzle:           Marker2D      = $cleaner/Nozzle
@onready var spray_particles: GPUParticles2D = $SprayParticles
@onready var ui                              = $TWUI

var _glitter_star_tex: Texture2D = null

# ============================================================
# GAME STATE
# ============================================================
enum GameState { WAITING, START, SPAWN, MOVE, SUCCESS, FAILURE, STOP, DONE }
var _game_state: GameState = GameState.WAITING
var _is_game_started: bool = false
var _run_once: bool = false
var _event_delay_timer: float = 0.0

var score:     int = 0
var n_targets: int = 0
var n_success: int = 0

var time_left: float = 60.0

var _stain_timeout: float = 20.0

# ============================================================
# CLOTH
# ============================================================
var cloth_x: float = 960.0
var cloth_y: float = 500.0

# ============================================================
# STAIN
# ============================================================
var stain_sprite:  Sprite2D     = null
var stain_image:   Image        = null
var stain_texture: ImageTexture = null
var stain_center:  Vector2      = Vector2.ZERO

var total_stain_pixels:  int   = 0
var total_stain_alpha:   float = 0.0   # sum of initial alpha values (for progress bar)
var total_alpha_removed: float = 0.0
var pixels_remaining:    int   = 0     # opaque pixels still left — hits 0 = truly done
var stain_done:          bool  = false
var center_touched:      bool  = false
var is_animating:        bool  = false

var stain_world_left:   float = 0.0
var stain_world_right:  float = 0.0
var last_stain_center:  Vector2 = Vector2(-9999.0, -9999.0)

var _stain_timer: float = 0.0   # counts down per stain

# ============================================================
# DEVICE STATE
# ============================================================
var _angle_min:       float = 0.0
var _angle_max:       float = 110.0
var _grip_threshold:  float = 10.0
var _waiting_release: bool  = false
var _at_center:       bool  = false
var _stain_pulse_tw:  Tween = null
var _cleaner_visible: bool    = false
var _cleaner_rest_pos: Vector2 = Vector2.ZERO
var _shake_tw: Tween = null
var _blink_tw: Tween = null
var _is_spraying: bool = false


# ============================================================
# READY
# ============================================================
func _ready() -> void:
	cloth.z_index   = 2
	cleaner.z_index = 3
	cloth.visible   = false
	cleaner.visible = false
	_glitter_star_tex = load("res://assets/tablewipping/glitter_star.png")
	_load_assessment_data()
	ui.show_start()


func _is_handle_mode() -> bool:
	return Appdata.selected_mechanism != null and Appdata.selected_mechanism.name == "HANDLE"


func _is_grip_mode() -> bool:
	return Appdata.selected_mechanism != null and Appdata.selected_mechanism.name == "GRIP"


func _load_assessment_data() -> void:
	if Appdata.selected_game == null:
		return
	var g := Appdata.selected_game
	_angle_min      = g.angle_min
	_angle_max      = g.angle_max
	_grip_threshold = g.grip_threshold
	_stain_timeout  = g.get_speed_mode_parameter(g.selected_difficulty)


# ============================================================
# PROCESS — WAITING state input only
# ============================================================
func _process(_delta: float) -> void:
	if _game_state == GameState.WAITING:
		if Input.is_action_just_pressed("ui_select"):
			_is_game_started = true


# ============================================================
# PHYSICS — game logic
# ============================================================
func _physics_process(delta: float) -> void:
	if _waiting_release and _game_state == GameState.MOVE:
		if (_is_handle_mode() or _is_grip_mode()) and HCcomm.device_is_connected:
			if HCcomm.get_total_force() < _grip_threshold:
				_waiting_release = false
			else:
				_run_game_state_machine(delta)
				return
		else:
			_waiting_release = false
	if _game_state in [GameState.MOVE, GameState.SUCCESS, GameState.FAILURE]:
		# Cloth X movement — knob angle (arrow keys as fallback)
		var prev_x := cloth_x
		if HCcomm.device_is_connected and Appdata.selected_mechanism != null:
			var a_max: float = _angle_max if _angle_max != _angle_min else _angle_min + 1.0
			cloth_x = remap(_get_knob_angle(), _angle_min, a_max,
				GameDefs.TableWipping.PLAY_LEFT  + GameDefs.TableWipping.CLOTH_WIDTH * 0.5,
				GameDefs.TableWipping.PLAY_RIGHT - GameDefs.TableWipping.CLOTH_WIDTH * 0.5)
		else:
			if Input.is_action_pressed("ui_left"):
				cloth_x -= GameDefs.TableWipping.CLOTH_SPEED * delta
			if Input.is_action_pressed("ui_right"):
				cloth_x += GameDefs.TableWipping.CLOTH_SPEED * delta
		cloth_x = clamp(cloth_x, GameDefs.TableWipping.PLAY_LEFT + GameDefs.TableWipping.CLOTH_WIDTH * 0.5, GameDefs.TableWipping.PLAY_RIGHT - GameDefs.TableWipping.CLOTH_WIDTH * 0.5)
		var dx: float = cloth_x - prev_x

		# Sprite2D uses centre position; flip and skew based on movement direction
		cloth.position = Vector2(cloth_x, cloth_y)
		if dx > 0.0:
			cloth.flip_h = false
		elif dx < 0.0:
			cloth.flip_h = true
		var target_skew: float = deg_to_rad(10.0) if dx > 0.0 else (deg_to_rad(-10.0) if dx < 0.0 else 0.0)
		cloth.skew = lerp(cloth.skew, target_skew, 12.0 * delta)

		# Erase logic: knob mode = auto-spray on proximity; handle mode = force triggers spray
		if stain_sprite != null and not stain_done:
			var dist: float = abs(cloth_x - stain_center.x)
			if _is_handle_mode() or _is_grip_mode():
				var is_forcing := HCcomm.device_is_connected and HCcomm.get_total_force() >= _grip_threshold
				var in_zone    := dist <= GameDefs.TableWipping.CENTER_TOUCH_ZONE
				# Trigger bottle descent + blink on zone entry (before any press)
				if in_zone and not center_touched and not is_animating:
					if not _at_center:
						_at_center = true
						_stop_stain_pulse()
					center_touched = true
					_play_cleaner_animation()
				elif not in_zone and _at_center and not center_touched:
					_at_center = false
					_stop_stain_pulse()
				if _cleaner_visible:
					if is_forcing:
						# Grip pressed: track hand, spray continuously, erase
						_stop_blink()
						spray_particles.emitting = true
						spray_particles.global_position = nozzle.global_position
						if not _is_spraying:
							_start_spray()
						cleaner.position.x = cloth_x
						_cleaner_rest_pos.x = cloth_x
						if dist > GameDefs.TableWipping.CENTER_DEAD_ZONE:
							_try_erase()
					else:
						# Grip released: stop spray, blink waiting — bottle stays visible
						if _is_spraying:
							_stop_spray()
						_start_blink()
			else:
				if dist <= GameDefs.TableWipping.CENTER_TOUCH_ZONE and not center_touched:
					center_touched = true
					_play_cleaner_animation()
				if center_touched and not is_animating:
					if _is_spraying:
						spray_particles.emitting = true
						spray_particles.global_position = nozzle.global_position
						if dist > GameDefs.TableWipping.CENTER_DEAD_ZONE:
							_try_erase()

		# Stain timeout check
		if not stain_done:
			_stain_timer -= delta
			ui.update_stain_timer(_stain_timer, _stain_timeout)
			if _stain_timer <= 0.0:
				_on_stain_timeout()

	_run_game_state_machine(delta)
	var _tgt: Vector2 = stain_center if stain_sprite != null else Vector2.ZERO
	AppdataTrial.set_game_context(GameState.keys()[_game_state], cloth_x, cloth_y, _tgt.x, _tgt.y)


# ============================================================
# STATE MACHINE
# ============================================================
func _run_game_state_machine(delta: float) -> void:
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
			_game_state = GameState.SPAWN

		GameState.SPAWN:
			if not _run_once:
				_spawn_stain()
				_stain_timer = _stain_timeout
				_run_once = true
				_game_state = GameState.MOVE

		GameState.MOVE:
			if is_time_up:
				_game_state = GameState.STOP
			# SUCCESS/FAILURE transitions happen via _on_stain_cleared / _on_stain_timeout

		GameState.SUCCESS, GameState.FAILURE:
			_event_delay_timer -= delta
			if _event_delay_timer <= 0.0:
				_run_once = false
				if is_time_up:
					_game_state = GameState.STOP
				else:
					_game_state = GameState.SPAWN

		GameState.STOP:
			_end_game()
			_game_state = GameState.DONE

		GameState.DONE:
			pass


# ============================================================
# GAME FLOW
# ============================================================
func _initialize_game() -> void:
	score     = 0
	n_targets = 0
	n_success = 0
	time_left = GameDefs.TableWipping.GAME_DURATION
	cloth.visible = true
	_run_once = false
	_waiting_release = false
	_event_delay_timer = 0.0
	ui.update_score(0)
	ui.update_timer(GameDefs.TableWipping.GAME_DURATION)
	ui.update_progress(0.0)
	ui.show_playing()
	AppDataTrial.start_new_trial()
	ScAudioManager.play_background_music("res://assets/audio/tw_bg.mp3")
	print("🧹 TW Game started — 60s trial")


func _end_game() -> void:
	_clear_stain()
	cloth.visible = false
	AppDataTrial.stop_trial(n_targets, n_success, n_targets - n_success)
	ScAudioManager.stop_music()
	ScAudioManager.play_gameover()

	var g := Appdata.selected_game
	var expected: int = g.expected_targets if g != null else n_targets
	var _card := Appdata.show_achievement(score, n_success, expected)
	_card.finished.connect(func(): ui.show_game_over(score, n_success, n_targets, expected))
	print("🏁 TW Game Over | Score:%d | %d/%d cleaned (expected %d)" % [score, n_success, n_targets, expected])


# ============================================================
# STAIN MANAGEMENT
# ============================================================
func _spawn_stain() -> void:
	_clear_stain()
	stain_done     = false
	center_touched = false
	_at_center     = false
	_stop_stain_pulse()

	# Random position — at least GameDefs.TableWipping.MIN_STAIN_DIST away from last stain
	var mx: float = GameDefs.TableWipping.STAIN_W * 0.5 + 30.0
	var my: float = GameDefs.TableWipping.STAIN_H * 0.5 + 30.0
	var sx: float
	var sy: float
	for _i in range(20):
		sx = randf_range(GameDefs.TableWipping.PLAY_LEFT + mx, GameDefs.TableWipping.PLAY_RIGHT - mx)
		sy = randf_range(GameDefs.TableWipping.PLAY_TOP  + my, GameDefs.TableWipping.PLAY_BOTTOM - my)
		if Vector2(sx, sy).distance_to(last_stain_center) >= GameDefs.TableWipping.MIN_STAIN_DIST:
			break
	stain_center = Vector2(sx, sy)

	# Pick random stain image
	var img_path: String = GameDefs.TableWipping.STAIN_PATHS[randi() % GameDefs.TableWipping.STAIN_PATHS.size()]

	stain_image = Image.load_from_file(img_path)
	if stain_image == null:
		push_error("TWGame: cannot load stain image: " + img_path)
		return

	# Ensure RGBA8 for pixel manipulation
	if stain_image.get_format() != Image.FORMAT_RGBA8:
		stain_image.convert(Image.FORMAT_RGBA8)

	stain_image.resize(GameDefs.TableWipping.STAIN_W, GameDefs.TableWipping.STAIN_H, Image.INTERPOLATE_BILINEAR)

	# Count opaque pixels (the "real" stain area)
	total_stain_pixels  = 0
	total_stain_alpha   = 0.0
	total_alpha_removed = 0.0
	for py in range(stain_image.get_height()):
		for px in range(stain_image.get_width()):
			var a := stain_image.get_pixel(px, py).a
			if a > 0.01:
				total_stain_pixels += 1
				total_stain_alpha  += a

	if total_stain_alpha <= 0.0:
		total_stain_alpha = float(GameDefs.TableWipping.STAIN_W * GameDefs.TableWipping.STAIN_H)   # fallback
	pixels_remaining = total_stain_pixels

	# Build live texture
	stain_texture        = ImageTexture.create_from_image(stain_image)
	stain_sprite         = Sprite2D.new()
	stain_sprite.texture = stain_texture
	stain_sprite.position = stain_center
	stain_sprite.z_index  = 1    # above background, Control (cloth) renders on top automatically
	add_child(stain_sprite)

	# World-space X bounds for quick overlap check
	stain_world_left  = stain_center.x - GameDefs.TableWipping.STAIN_W * 0.5
	stain_world_right = stain_center.x + GameDefs.TableWipping.STAIN_W * 0.5

	# Auto-snap cloth Y to stain Y
	cloth_y = stain_center.y
	cloth.position = Vector2(cloth_x, cloth_y)

	last_stain_center = stain_center
	n_targets   += 1
	ui.update_progress(0.0)
	ui.show_stain_timer(true)
	ui.update_stain_timer(_stain_timeout, _stain_timeout)

	print("🧹 Stain spawned at (%.0f,%.0f) | opaque pixels: %d" % [sx, sy, total_stain_pixels])


func _clear_stain() -> void:
	_stop_stain_pulse()
	_stop_shake()
	_stop_blink()
	_stop_spray()
	_at_center = false
	is_animating = false
	_cleaner_visible = false
	cleaner.visible = false
	cleaner.modulate.a = 1.0
	if stain_sprite != null:
		stain_sprite.queue_free()
		stain_sprite  = null
		stain_image   = null
		stain_texture = null


# ============================================================
# ERASURE
# ============================================================
func _try_erase() -> void:
	# Quick X bounds check before doing any pixel work
	var cloth_right := cloth_x + GameDefs.TableWipping.CLOTH_WIDTH * 0.5
	var cloth_left  := cloth_x - GameDefs.TableWipping.CLOTH_WIDTH * 0.5
	if cloth_right < stain_world_left or cloth_left > stain_world_right:
		return

	_erase_at(cloth_x, cloth_y)


func _erase_at(wx: float, wy: float) -> void:
	if stain_image == null:
		return

	# World → image pixel centre
	var cx := int((wx - stain_center.x) + GameDefs.TableWipping.STAIN_W * 0.5)
	var cy := int((wy - stain_center.y) + GameDefs.TableWipping.STAIN_H * 0.5)

	var rx:    int   = GameDefs.TableWipping.BRUSH_RX
	var ry:    int   = GameDefs.TableWipping.BRUSH_RY
	var rx_sq: float = float(rx * rx)
	var ry_sq: float = float(ry * ry)
	var tw:    int   = stain_image.get_width()
	var th:    int   = stain_image.get_height()

	var alpha_removed: float = 0.0

	for i in range(-rx, rx + 1):
		for j in range(-ry, ry + 1):
			# Ellipse test: (i/rx)² + (j/ry)² ≤ 1
			if float(i * i) / rx_sq + float(j * j) / ry_sq > 1.0:
				continue
			var px := cx + i
			var py := cy + j
			if px < 0 or py < 0 or px >= tw or py >= th:
				continue
			var c := stain_image.get_pixel(px, py)
			if c.a > 0.01:
				var removed := minf(c.a, GameDefs.TableWipping.ALPHA_DECREMENT)
				c.a -= removed
				if c.a <= 0.01:
					pixels_remaining -= 1
				stain_image.set_pixel(px, py, c)
				alpha_removed += removed

	if alpha_removed > 0.0:
		total_alpha_removed += alpha_removed
		stain_texture.update(stain_image)
		var pct := total_alpha_removed / total_stain_alpha
		ui.update_progress(minf(pct, 1.0))
		if pct >= GameDefs.TableWipping.ERASE_THRESHOLD:
			_on_stain_cleared()


func _on_stain_cleared() -> void:
	if stain_done:
		return
	stain_done = true
	score     += 1
	n_success += 1
	if stain_sprite != null:
		stain_sprite.visible = false
	_hide_cleaner()
	_show_glitter_stars()
	print("✅ Stain cleared! Score: %d" % score)
	ScAudioManager.play_sc_success()
	ui.update_score(score)
	ui.show_stain_timer(false)
	var stain_top := Vector2(stain_center.x, stain_center.y - GameDefs.TableWipping.STAIN_H * 0.5)
	ui.show_success_popup(stain_top)
	# State machine handles the delay and next spawn
	if _is_handle_mode() or _is_grip_mode():
		_waiting_release = true
	_event_delay_timer = GameDefs.TableWipping.GLITTER_DURATION
	_game_state = GameState.SUCCESS
	_run_once = false


func _on_stain_timeout() -> void:
	if stain_done:
		return
	stain_done = true
	print("⏰ Stain timeout — moving to next stain")
	ui.show_stain_timer(false)
	_clear_stain()
	_event_delay_timer = GameDefs.TableWipping.RESULT_DELAY
	_game_state = GameState.FAILURE
	_run_once = false


func _show_glitter_stars() -> void:
	if _glitter_star_tex == null:
		return
	var half_w := GameDefs.TableWipping.STAIN_W * 0.45
	var half_h := GameDefs.TableWipping.STAIN_H * 0.45
	for _i in range(GameDefs.TableWipping.GLITTER_COUNT):
		var star := Sprite2D.new()
		star.texture  = _glitter_star_tex
		star.z_index  = 5
		star.position = Vector2(
			stain_center.x + randf_range(-half_w, half_w),
			stain_center.y + randf_range(-half_h, half_h)
		)
		var base_s := randf_range(0.06, 0.16)
		star.scale    = Vector2(base_s, base_s)
		star.rotation = randf_range(0.0, TAU)
		star.modulate.a = 0.0
		add_child(star)

		var delay  := randf_range(0.0, 0.35)
		var period := randf_range(0.45, 0.75)

		# Continuous spin
		var rot_tw := create_tween().set_loops()
		rot_tw.tween_property(star, "rotation",
			star.rotation + TAU, period).set_trans(Tween.TRANS_LINEAR)

		# Scale pulse (blink)
		var bs        := star.scale
		var blink_tw  := create_tween().set_loops()
		blink_tw.tween_property(star, "scale", bs * 1.6, 0.18).set_trans(Tween.TRANS_SINE)
		blink_tw.tween_property(star, "scale", bs * 0.6, 0.18).set_trans(Tween.TRANS_SINE)

		# Lifecycle: fade in → hold → fade out → free
		var hold    := maxf(GameDefs.TableWipping.GLITTER_DURATION - delay - 0.15 - 0.4, 0.05)
		var life_tw := create_tween()
		life_tw.tween_interval(delay)
		life_tw.tween_property(star, "modulate:a", 1.0, 0.15)
		life_tw.tween_interval(hold)
		life_tw.tween_property(star, "modulate:a", 0.0, 0.4)
		life_tw.tween_callback(func():
			rot_tw.kill()
			blink_tw.kill()
			if is_instance_valid(star):
				star.queue_free()
		)


# ============================================================
# CLEANER ANIMATION
# ============================================================
func _start_stain_pulse() -> void:
	if stain_sprite == null:
		return
	if _stain_pulse_tw and _stain_pulse_tw.is_valid():
		_stain_pulse_tw.kill()
	_stain_pulse_tw = create_tween().set_loops()
	_stain_pulse_tw.tween_property(stain_sprite, "scale", Vector2(1.09, 1.09), 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_stain_pulse_tw.tween_property(stain_sprite, "scale", Vector2(1.0, 1.0), 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_stain_pulse() -> void:
	if _stain_pulse_tw and _stain_pulse_tw.is_valid():
		_stain_pulse_tw.kill()
	_stain_pulse_tw = null
	if stain_sprite and is_instance_valid(stain_sprite):
		stain_sprite.scale = Vector2(1.0, 1.0)


func _play_cleaner_animation() -> void:
	is_animating    = true
	cleaner.visible = true
	cleaner.modulate.a = 1.0

	# Compute target position so nozzle lands on the stain centre.
	cleaner.position = Vector2(stain_center.x, 0.0)
	var nozzle_offset: Vector2 = nozzle.global_position - cleaner.global_position
	var stain_top: Vector2     = Vector2(stain_center.x, stain_center.y - GameDefs.TableWipping.STAIN_H * 0.5)
	var target_pos: Vector2    = stain_top - nozzle_offset

	# Start off-screen above, then slide in
	cleaner.position = Vector2(target_pos.x, -200.0)
	var tween := create_tween()
	tween.tween_property(cleaner, "position", target_pos, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

	_cleaner_rest_pos = target_pos
	_cleaner_visible  = true
	is_animating      = false
	if _is_handle_mode() or _is_grip_mode():
		# Blink to signal "press grip now"
		_start_blink()
	else:
		# Knob mode: auto-spray immediately after descent
		_start_spray()


func _start_blink() -> void:
	if _blink_tw and _blink_tw.is_valid():
		return
	_blink_tw = create_tween().set_loops()
	_blink_tw.tween_property(cleaner, "modulate:a", 0.25, 0.28).set_trans(Tween.TRANS_SINE)
	_blink_tw.tween_property(cleaner, "modulate:a", 1.0,  0.28).set_trans(Tween.TRANS_SINE)


func _stop_blink() -> void:
	if _blink_tw and _blink_tw.is_valid():
		_blink_tw.kill()
	_blink_tw = null
	if is_instance_valid(cleaner):
		cleaner.modulate.a = 1.0


func _start_spray() -> void:
	_is_spraying = true
	spray_particles.global_position = nozzle.global_position
	spray_particles.emitting = true
	ScAudioManager.play_tw_spray()


func _stop_spray() -> void:
	_is_spraying = false
	spray_particles.emitting = false


func _start_shake() -> void:
	if _shake_tw and _shake_tw.is_valid():
		return
	var ox := 10.0
	_shake_tw = create_tween().set_loops()
	_shake_tw.tween_property(cleaner, "position:x", _cleaner_rest_pos.x + ox, 0.04).set_trans(Tween.TRANS_SINE)
	_shake_tw.tween_property(cleaner, "position:x", _cleaner_rest_pos.x - ox, 0.04).set_trans(Tween.TRANS_SINE)
	_shake_tw.tween_property(cleaner, "position:x", _cleaner_rest_pos.x,      0.03).set_trans(Tween.TRANS_SINE)


func _stop_shake() -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	_shake_tw = null
	if is_instance_valid(cleaner):
		cleaner.position.x = _cleaner_rest_pos.x


func _hide_cleaner() -> void:
	if not _cleaner_visible:
		return
	_stop_blink()
	_stop_spray()
	_cleaner_visible = false
	center_touched   = false
	cleaner.modulate.a = 1.0
	var hide_tw := create_tween()
	hide_tw.tween_property(cleaner, "position:y", -200.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	hide_tw.tween_callback(func(): cleaner.visible = false)


# ============================================================
# DEVICE HELPERS
# ============================================================
func _get_knob_angle() -> float:
	if Appdata.selected_mechanism == null:
		return HCcomm.angle_2
	match Appdata.selected_mechanism.name:
		"HANDLE", "GRIP": return HCcomm.angle_1
		"KEY KNOB":       return HCcomm.angle_3
		"FINE KNOB":      return HCcomm.angle_4
		_:                return HCcomm.angle_2


# ============================================================
# NAVIGATION (called by UI buttons)
# ============================================================
func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func exit_game() -> void:
	if _game_state in [GameState.WAITING, GameState.DONE]:
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		_game_state = GameState.STOP
