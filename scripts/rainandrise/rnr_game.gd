class_name RNRGame
extends Node2D

# ============================================================
# CONSTANTS
# ============================================================
const PLAY_LEFT:    float = 100.0
const PLAY_RIGHT:   float = 1800.0

const CLOUD_Y:      float = 150.0
const CLOUD_SPEED:  float = 600.0
const CLOUD_HALF_W: float = 140.0

const SEED_COUNT:   int   = 5
const SEED_Y:       float = 1000.0  # grass visual surface (texture row 583 → world y≈1002)
const SEED_HALF_W:  float = 60.0

const HIGHLIGHT_DURATION: float = 4.0
const RAIN_TO_GROW:       float = 1.0
const SPAWN_DELAY:        float = 0.05
const RESULT_DELAY:       float = 0.6
const EMOTION_INTERVAL:   float = 12.0
const GAME_DURATION:      float = 60.0

const CLOUD_SCALE:  float = 0.4
const SEED_SCALE:   float = 0.25

const SEED_XS: PackedFloat64Array = [235.0, 558.0, 881.0, 1204.0, 1527.0]

const RAIN_DROP_COUNT: int   = 100
const RAIN_DROP_SPEED: float = 500.0
const DRAIN_RATE:      float = 0.4    # water lost per second while raining  (full→empty in 2.5s)
const FILL_RATE:       float = 0.5   # water gained per second while stopped (empty→full in 4s)

# ============================================================
# NODES
# ============================================================
@onready var _seed_container: Node2D   = $SeedContainer
@onready var _cloud_sprite:   Sprite2D = $CloudSprite
@onready var _rain_container: Node2D   = $CloudSprite/RainContainer
@onready var ui                         = $RNRUI

# ============================================================
# STATE MACHINE
# ============================================================
enum GameState { WAITING, START, SPAWNSEED, MOVE, SUCCESS, FAILURE, STOP, DONE }
var _game_state: GameState = GameState.WAITING

var _is_game_started:   bool  = false
var _run_once:          bool  = false
var _event_delay_timer: float = 0.0

# ============================================================
# SCORE
# ============================================================
var score:     int   = 0
var n_targets: int   = 0
var n_success: int   = 0
var n_failure: int   = 0
var time_left: float = GAME_DURATION

# ============================================================
# CLOUD
# ============================================================
var cloud_x:        float = 960.0
var _emotion_timer: float = 0.0
var _is_raining:    bool  = false

# ============================================================
# DEVICE STATE
# ============================================================
var _angle_min:       float = 0.0
var _angle_max:       float = 110.0
var _max_force:       float = 100.0
var _rain_threshold:  float = 10.0
var _cloud_water:     float = 1.0
var _waiting_release: bool  = false

# ============================================================
# SEEDS
# ============================================================
var _seed_sprites: Array = []
var _seed_stages:  Array = []
var _seed_glows:   Array = []   # pulsing radial glow Sprite2D
var _seed_rays:    Array = []   # rotating starburst rays Sprite2D
var _highlighted:     int   = -1
var _highlight_timer: float = 0.0
var _rain_timer:      float = 0.0

# ============================================================
# TEXTURES
# ============================================================
var _stage_textures: Array     = []
var _cloud_emotions: Array     = []
var _rain_drop_tex:  Texture2D = null
var _glow_tex:       Texture2D = null
var _ray_tex:        Texture2D = null
var _rain_drops:     Array     = []


# ============================================================
# READY
# ============================================================
func _ready() -> void:
	_load_textures()
	_setup_cloud()
	_setup_seeds()
	_setup_rain_drops()
	_load_assessment_data()
	ui.show_start()


func _is_knob_mode() -> bool:
	if Appdata.selected_mechanism == null:
		return false
	return Appdata.selected_mechanism.name in ["KNOB", "FINE KNOB", "KEY KNOB"]


func _is_pinch_mode() -> bool:
	if Appdata.selected_mechanism == null:
		return false
	return Appdata.selected_mechanism.name in ["PINCH", "BUTTONS"]


func _read_active_input() -> bool:
	if not (HCcomm and HCcomm.device_is_connected):
		return false
	var mech = Appdata.selected_mechanism
	if mech == null:
		return false
	if mech.name == "PINCH":
		var rom := mech.old_rom as PinchROM
		if rom == null:
			return HCcomm.button_7 == 0 or HCcomm.button_6 == 0
		return (rom.pinch1_done and HCcomm.button_7 == 0) or \
			   (rom.pinch2_done and HCcomm.button_6 == 0)
	if mech.name == "BUTTONS":
		return HCcomm.button_1==0 or HCcomm.button_2==0 or HCcomm.button_3==0 \
			   or HCcomm.button_4==0 or HCcomm.button_5==0
	return false


func _get_cloud_angle() -> float:
	if Appdata.selected_mechanism == null:
		return HCcomm.angle_1
	match Appdata.selected_mechanism.name:
		"KNOB":      return HCcomm.angle_2
		"FINE KNOB": return HCcomm.angle_4
		"KEY KNOB":  return HCcomm.angle_3
		_:           return HCcomm.angle_1


func _load_assessment_data() -> void:
	if _is_knob_mode():
		var arom := Appdata.selected_mechanism.get_current_arom()
		_angle_min = arom[0]
		_angle_max = arom[1]
	elif _is_pinch_mode():
		pass  # no AROM for pinch button — fixed threshold used
	else:
		var handle_rom := ROM.new("HANDLE", true)
		if handle_rom.is_arom_set():
			_angle_min = handle_rom.arom_min
			_angle_max = handle_rom.arom_max
		var grip_rom := ROM.new("GRIP", true)
		if grip_rom.is_arom_set():
			_max_force = grip_rom.arom_max
			_rain_threshold = _max_force * 0.1


func _load_textures() -> void:
	var stage_paths := [
		"res://assets/rainandrise/Seed/seed.png",
		"res://assets/rainandrise/GreenPlant/2ndSt.png",
		"res://assets/rainandrise/GreenPlant/3rdST.png",
		"res://assets/rainandrise/GreenPlant/4thStage.png",
		"res://assets/rainandrise/GreenPlant/lastST.png",
	]
	for p in stage_paths:
		_stage_textures.append(load(p) if ResourceLoader.exists(p) else null)

	var emotion_ids := [0,1,2,3,4,6,7,8,9,10,12,13,14,15,16,18,19,20,22,24,25,26,27,28]
	for idx in emotion_ids:
		var p := "res://assets/rainandrise/CloudEmotions/tile%03d.png" % idx
		if ResourceLoader.exists(p):
			_cloud_emotions.append(load(p))

	# Raindrop texture
	var dimg := Image.create(5, 18, false, Image.FORMAT_RGBA8)
	dimg.fill(Color(0.45, 0.75, 1.0, 0.85))
	_rain_drop_tex = ImageTexture.create_from_image(dimg)

	# Sunlight glow — warm radial gradient, yellow-white center fading to transparent
	var gs := 180
	var gimg := Image.create(gs, gs, false, Image.FORMAT_RGBA8)
	var gcenter := Vector2(gs * 0.5, gs * 0.5)
	for py in gs:
		for px in gs:
			var d := Vector2(px, py).distance_to(gcenter)
			var t := clampf(1.0 - d / (gs * 0.5), 0.0, 1.0)
			var a := t * t * 0.92
			# warm white-yellow color
			gimg.set_pixel(px, py, Color(1.0, 0.96, 0.4, a))
	_glow_tex = ImageTexture.create_from_image(gimg)

	# Starburst rays — 16 sharp rays rotating around center
	var rs := 160
	var rimg := Image.create(rs, rs, false, Image.FORMAT_RGBA8)
	var rcenter := Vector2(rs * 0.5, rs * 0.5)
	for py in rs:
		for px in rs:
			var dx := float(px) - rcenter.x
			var dy := float(py) - rcenter.y
			var dist := sqrt(dx * dx + dy * dy)
			if dist < 10.0 or dist >= rcenter.x:
				continue
			var angle := atan2(dy, dx)
			var ray := pow(absf(sin(angle * 8.0)), 5.0)  # 16 sharp rays
			var fade := clampf(1.0 - (dist - 10.0) / (rcenter.x - 10.0), 0.0, 1.0)
			var a := ray * fade * 0.78
			rimg.set_pixel(px, py, Color(1.0, 0.88, 0.15, a))
	_ray_tex = ImageTexture.create_from_image(rimg)


func _setup_cloud() -> void:
	if _cloud_emotions.size() > 0:
		_cloud_sprite.texture = _cloud_emotions[0]
	_cloud_sprite.scale    = Vector2(CLOUD_SCALE, CLOUD_SCALE)
	_cloud_sprite.position = Vector2(cloud_x, CLOUD_Y)
	_cloud_sprite.visible  = false


func _setup_seeds() -> void:
	for i in SEED_COUNT:
		var node := Node2D.new()
		node.position = Vector2(SEED_XS[i], SEED_Y)
		_seed_container.add_child(node)

		# Glow — at plant base (node position = grass level), above grass z=3
		var glow := Sprite2D.new()
		glow.texture  = _glow_tex
		glow.z_index  = 6
		glow.visible  = false
		glow.position = Vector2(0, -20.0)
		glow.scale    = Vector2(0.9, 0.9)
		node.add_child(glow)
		_seed_glows.append(glow)

		# Rays — same base position as glow, rotates above grass
		var rays := Sprite2D.new()
		rays.texture  = _ray_tex
		rays.z_index  = 6
		rays.visible  = false
		rays.position = Vector2(0, -20.0)
		node.add_child(rays)
		_seed_rays.append(rays)

		# Plant/seed sprite — anchored bottom-to-ground via offset, above grass z=3
		var spr := Sprite2D.new()
		var tex0: Texture2D = _stage_textures[0] if _stage_textures.size() > 0 else null
		spr.texture  = tex0
		spr.scale    = Vector2(SEED_SCALE, SEED_SCALE)
		spr.z_index  = 5
		spr.position = Vector2.ZERO
		if tex0:
			spr.offset = Vector2(0, -tex0.get_height() / 2.0)
		node.add_child(spr)
		_seed_sprites.append(spr)
		_seed_stages.append(0)


func _setup_rain_drops() -> void:
	# Counteract CloudSprite's (0.5,0.5) scale so drop positions are direct world offsets from cloud
	_rain_container.scale = Vector2(1.0 / CLOUD_SCALE, 1.0 / CLOUD_SCALE)
	for i in RAIN_DROP_COUNT:
		var drop := Sprite2D.new()
		drop.texture  = _rain_drop_tex
		drop.visible  = false
		drop.z_index  = 6
		drop.position = Vector2(randf_range(-90.0, 90.0), 70.0 + i * 7.0)
		_rain_container.add_child(drop)
		_rain_drops.append(drop)


# ============================================================
# INPUT  (WAITING → START)
# ============================================================
func _process(_delta: float) -> void:
	if _game_state == GameState.WAITING:
		if Input.is_action_just_pressed("ui_select"):
			_is_game_started = true


# ============================================================
# PHYSICS
# ============================================================
func _physics_process(delta: float) -> void:
	match _game_state:
		GameState.MOVE, GameState.SUCCESS, GameState.FAILURE:
			_update_cloud(delta)
			_update_emotion(delta)

	_update_rain_visual(delta)
	_run_game_state_machine(delta)
	var _tgt_x: float = SEED_XS[_highlighted] if _highlighted >= 0 else 0.0
	var _tgt_y: float = SEED_Y if _highlighted >= 0 else 0.0
	AppDataTrial.set_game_context(GameState.keys()[_game_state], cloud_x, CLOUD_Y, _tgt_x, _tgt_y)


func _update_cloud(delta: float) -> void:
	var squeezing := false

	if _waiting_release and not _is_knob_mode():
		if HCcomm and HCcomm.device_is_connected:
			var released := (not _read_active_input()) if _is_pinch_mode() \
				else HCcomm.get_total_force() < _rain_threshold
			if released:
				_waiting_release = false
			else:
				cloud_x = clamp(cloud_x, PLAY_LEFT + CLOUD_HALF_W, PLAY_RIGHT - CLOUD_HALF_W)
				_cloud_sprite.position.x = cloud_x
				_cloud_sprite.modulate.a = lerp(0.3, 1.0, _cloud_water)
				return
		else:
			_waiting_release = false

	if HCcomm and HCcomm.device_is_connected:
		if _is_pinch_mode():
			# Cloud auto-targets the highlighted seed; any button triggers rain
			if _highlighted >= 0:
				cloud_x = move_toward(cloud_x, SEED_XS[_highlighted], CLOUD_SPEED * delta)
			squeezing = _read_active_input()
		else:
			var a_max := _angle_max if _angle_max != _angle_min else _angle_min + 110.0
			var t := clampf(inverse_lerp(_angle_min, a_max, _get_cloud_angle()), 0.0, 1.0)
			cloud_x = lerp(PLAY_LEFT + CLOUD_HALF_W, PLAY_RIGHT - CLOUD_HALF_W, t)
			if _is_knob_mode():
				squeezing = _game_state == GameState.MOVE and _highlighted >= 0 \
					and absf(cloud_x - SEED_XS[_highlighted]) <= CLOUD_HALF_W + SEED_HALF_W
			else:
				squeezing = HCcomm.get_total_force() >= _rain_threshold
	else:
		if Input.is_action_pressed("ui_left"):
			cloud_x -= CLOUD_SPEED * delta
		if Input.is_action_pressed("ui_right"):
			cloud_x += CLOUD_SPEED * delta
		squeezing = Input.is_key_pressed(KEY_R)

	if _is_pinch_mode():
		# Pinch button: rain on/off with button press, no cloud drain
		_is_raining = squeezing
	elif squeezing and _cloud_water > 0.0:
		_is_raining = true
		_cloud_water = maxf(_cloud_water - DRAIN_RATE * delta, 0.0)
	elif not squeezing:
		_is_raining = false
		_cloud_water = minf(_cloud_water + FILL_RATE * delta, 1.0)
	else:
		_is_raining = false  # squeezing but cloud is empty — wait for release

	cloud_x = clamp(cloud_x, PLAY_LEFT + CLOUD_HALF_W, PLAY_RIGHT - CLOUD_HALF_W)
	_cloud_sprite.position.x = cloud_x
	_cloud_sprite.modulate.a = lerp(0.3, 1.0, _cloud_water)


func _update_emotion(delta: float) -> void:
	_emotion_timer += delta
	if _emotion_timer >= EMOTION_INTERVAL and _cloud_emotions.size() > 0:
		_emotion_timer = 0.0
		_cloud_sprite.texture = _cloud_emotions[randi() % _cloud_emotions.size()]


func _update_rain_visual(delta: float) -> void:
	var raining := _is_raining and _game_state == GameState.MOVE
	var max_y := (SEED_Y - CLOUD_Y) + 60
	for drop in _rain_drops:
		drop.visible = raining
		if raining:
			drop.position.y += RAIN_DROP_SPEED * delta
			if drop.position.y > max_y:
				drop.position.y = 70.0
				drop.position.x = randf_range(-90.0, 90.0)

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
			_game_state = GameState.SPAWNSEED

		GameState.SPAWNSEED:
			if _event_delay_timer <= 0.0 and not _run_once:
				_highlight_next_seed()
				_event_delay_timer = SPAWN_DELAY
				_run_once = true
			else:
				_event_delay_timer -= delta
				if _event_delay_timer <= 0.0:
					_game_state = GameState.MOVE

		GameState.MOVE:
			_highlight_timer += delta

			if _highlighted >= 0 and _is_raining:
				var dx := absf(cloud_x - SEED_XS[_highlighted])
				if dx <= CLOUD_HALF_W + SEED_HALF_W:
					_rain_timer = minf(_rain_timer + delta, RAIN_TO_GROW)
				else:
					_rain_timer = maxf(_rain_timer - delta, 0.0)
			else:
				_rain_timer = maxf(_rain_timer - delta, 0.0)

			_animate_highlight(delta)

			if _rain_timer >= RAIN_TO_GROW:
				_on_success()
				_event_delay_timer = RESULT_DELAY
				_game_state = GameState.SUCCESS
			elif _highlight_timer >= HIGHLIGHT_DURATION:
				_on_failure()
				_event_delay_timer = RESULT_DELAY
				_game_state = GameState.FAILURE

		GameState.SUCCESS, GameState.FAILURE:
			_event_delay_timer -= delta
			if _event_delay_timer <= 0.0:
				_run_once   = false
				_rain_timer = 0.0
				_game_state = GameState.STOP if is_time_up else GameState.SPAWNSEED

		GameState.STOP:
			_end_game()
			_game_state = GameState.DONE

		GameState.DONE:
			pass


func _animate_highlight(delta: float) -> void:
	if _highlighted < 0:
		return
	var glow := _seed_glows[_highlighted] as Sprite2D
	var rays := _seed_rays[_highlighted] as Sprite2D
	# Pulse glow scale and brightness
	var pulse := 1.2 + 0.30 * sin(_highlight_timer * 4.0)
	glow.scale    = Vector2(pulse, pulse)
	# glow.modulate = Color(1.0, 0.95, 0.5, 0.6 + 0.4 * sin(_highlight_timer * 3.0))
	# Slowly rotate rays
	rays.rotation  += delta * 0.65
	# rays.modulate.a = 0.55 + 0.35 * sin(_highlight_timer * 2.5 + 1.0)


# ============================================================
# GAME LIFECYCLE
# ============================================================
func _initialize_game() -> void:
	score     = 0
	n_targets = 0
	n_success = 0
	n_failure = 0
	time_left = GAME_DURATION
	cloud_x   = 960.0
	_cloud_sprite.position.x = cloud_x
	_cloud_sprite.visible    = true

	for i in SEED_COUNT:
		_seed_stages[i] = 0
		var spr0 := _seed_sprites[i] as Sprite2D
		if _stage_textures.size() > 0:
			spr0.texture = _stage_textures[0]
			if spr0.texture:
				spr0.offset = Vector2(0, -spr0.texture.get_height() / 2.0)
		(_seed_glows[i] as Sprite2D).visible = false
		(_seed_rays[i] as Sprite2D).visible  = false

	_highlighted     = -1
	_highlight_timer = 0.0
	_rain_timer      = 0.0
	_is_raining      = false
	_cloud_water     = 1.0
	_waiting_release = false
	_run_once        = false
	_event_delay_timer = 0.0

	ui.update_score(0)
	ui.update_timer(GAME_DURATION)
	ui.show_playing()

	AppDataTrial.start_new_trial()
	ScAudioManager.play_background_music("res://assets/audio/rnr_bg.mp3")
	print("🌧️ RainAndRise started — 60s")


func _end_game() -> void:
	for i in SEED_COUNT:
		(_seed_glows[i] as Sprite2D).visible = false
		(_seed_rays[i] as Sprite2D).visible  = false
	_cloud_sprite.visible    = false
	_cloud_sprite.modulate.a = 1.0
	_is_raining = false

	AppDataTrial.stop_trial(n_targets, n_success, n_failure)
	ScAudioManager.stop_music()
	ScAudioManager.play_gameover()
	ui.show_game_over(score, n_targets, n_success, n_failure)
	print("🏁 RainAndRise Over | Score:%d | %d/%d watered" % [score, n_success, n_targets])


# ============================================================
# SEED MANAGEMENT
# ============================================================
func _highlight_next_seed() -> void:
	if _highlighted >= 0:
		(_seed_glows[_highlighted] as Sprite2D).visible = false
		(_seed_rays[_highlighted] as Sprite2D).visible  = false

	_highlighted     = randi() % SEED_COUNT
	n_targets       += 1
	_highlight_timer = 0.0
	_rain_timer      = 0.0

	var glow := _seed_glows[_highlighted] as Sprite2D
	var rays := _seed_rays[_highlighted] as Sprite2D
	glow.scale    = Vector2(0.9, 0.9)
	glow.modulate = Color(1.0, 0.95, 0.5, 1.0)
	glow.visible  = true
	rays.rotation = 0.0
	rays.visible  = true
	if _is_pinch_mode():
		if n_targets > 1:
			_waiting_release = true
	elif not _is_knob_mode():
		_waiting_release = true


func _on_success() -> void:
	var idx := _highlighted
	(_seed_glows[idx] as Sprite2D).visible = false
	(_seed_rays[idx] as Sprite2D).visible  = false

	var next_stage: int = (int(_seed_stages[idx]) + 1) % _stage_textures.size()
	_seed_stages[idx] = next_stage
	var spr := _seed_sprites[idx] as Sprite2D
	spr.texture = _stage_textures[next_stage]
	if spr.texture:
		spr.offset = Vector2(0, -spr.texture.get_height() / 2.0)
	_animate_grow(idx)

	score     += 1
	n_success += 1
	ui.update_score(score)
	ui.show_success_popup()
	ScAudioManager.play_rnr_success()
	print("🌱 Seed %d → stage %d | Score: %d" % [idx, next_stage, score])


func _on_failure() -> void:
	if _highlighted >= 0:
		(_seed_glows[_highlighted] as Sprite2D).visible = false
		(_seed_rays[_highlighted] as Sprite2D).visible  = false
	n_failure += 1
	ui.show_failure_popup()
	ScAudioManager.play_cg_miss()


func _animate_grow(seed_idx: int) -> void:
	var spr := _seed_sprites[seed_idx] as Sprite2D
	var tw  := create_tween()
	tw.tween_property(spr, "scale", Vector2(SEED_SCALE * 1.4, SEED_SCALE * 1.4), 0.12) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "scale", Vector2(SEED_SCALE, SEED_SCALE), 0.18) \
		.set_ease(Tween.EASE_IN)


# ============================================================
# NAVIGATION
# ============================================================
func restart_game() -> void:
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func exit_game() -> void:
	if _game_state in [GameState.WAITING, GameState.DONE]:
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		_game_state = GameState.STOP
