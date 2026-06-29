class_name SC3DGame
extends Node3D

# ============================================================
# ASSET PATHS
# ============================================================
const P_ROAD     := "res://scene/safecrossing3D/road_tile.tscn"
const P_CROSSING := "res://scene/safecrossing3D/crossing_tile.tscn"
const P_JUNCTION := "res://scene/safecrossing3D/junction_tile.tscn"

const P_CHARS := [
	"res://assets/safecrossing3D/kenney_mini-characters/Models/GLB format/character-female-a.glb",
	"res://assets/safecrossing3D/kenney_mini-characters/Models/GLB format/character-male-a.glb",
	"res://assets/safecrossing3D/kenney_mini-characters/Models/GLB format/character-female-b.glb",
	"res://assets/safecrossing3D/kenney_mini-characters/Models/GLB format/character-male-b.glb",
]

const P_TRAFFIC := [
	"res://assets/safecrossing3D/kenney_car-kit/Models/GLB format/taxi.glb",
	"res://assets/safecrossing3D/kenney_car-kit/Models/GLB format/police.glb",
	"res://assets/safecrossing3D/kenney_car-kit/Models/GLB format/van.glb",
	"res://assets/safecrossing3D/kenney_car-kit/Models/GLB format/hatchback-sports.glb",
	"res://assets/safecrossing3D/kenney_car-kit/Models/GLB format/suv.glb",
	"res://assets/safecrossing3D/kenney_car-kit/Models/GLB format/ambulance.glb",
]

const P_BLDS := [
	"res://assets/safecrossing3D/kenney_city-kit-commercial_2.1/Models/GLB format/building-a.glb",
	"res://assets/safecrossing3D/kenney_city-kit-commercial_2.1/Models/GLB format/building-c.glb",
	"res://assets/safecrossing3D/kenney_city-kit-commercial_2.1/Models/GLB format/building-e.glb",
]
const P_LIGHT := "res://assets/safecrossing3D/kenney_city-kit-roads/Models/GLB format/light-curved.glb"

# ============================================================
# TUNING — Player / Road
# ============================================================
const TILE_SCALE  := 15.0
const CHAR_SCALE  := 2.5
const CAR_SPEED   := 12.0
const ACCEL       := 7.0
const BRAKE       := 24.0
const POOL_SIZE   := 22
const EVENT_GAP   := 85.0
const FIRST_EVENT := 55.0
const PED_SPEED   := 1.8
const PED_COUNT   := 3
const PED_SIDE_L  := -6.0
const PED_SIDE_R  :=  6.0
const PED_SPREAD  := 1.5
const GAME_DURATION := 60.0
const RESULT_PAUSE  := 1.5

# Collision radii
const COLL_X_PED     := 2.5   # ped X from road centre triggers hit
const COLL_Z_PED     := 2.5   # car–ped Z distance triggers hit
const COLL_X_TRAFFIC := 3.5   # traffic X from road centre triggers hit

# ============================================================
# TUNING — Traffic / Junction
# ============================================================
const TRAFFIC_SPEED  := 12.0
const TRAFFIC_SCALE  := 2.5
const TRAFFIC_COUNT  := 4      # cars per stream
const TRAFFIC_GAP    := 35.0   # gap between consecutive cars in a stream
const TRAFFIC_LANE   := 3.0    # Z offset of each lane from junction centre
# Derived (hardcoded to avoid const-eval quirks)
const TRAFFIC_X_HALF := 70.0   # = TRAFFIC_COUNT * TRAFFIC_GAP / 2
const TRAFFIC_LOOP   := 140.0  # = TRAFFIC_COUNT * TRAFFIC_GAP
const JUNCTION_HALF  := 7.5    # = TILE_SCALE / 2

# ============================================================
# TUNING — City pool
# ============================================================
const BLD_SCALE      := 3.0
const LIGHT_SCALE    := 10.0
const BLD_SPACING    := 40.0
const LIGHT_SPACING  := 25.0
const BLD_POOL_SIZE   := 8
const LIGHT_POOL_SIZE := 10
const BLD_X_R   :=  18.0
const BLD_X_L   := -18.0
const LIGHT_X_R :=   6.0
const LIGHT_X_L :=  -6.0

# ============================================================
# SCENE NODES
# ============================================================
@onready var _car_pivot         : Node3D = $CarPivot
@onready var _road_container    : Node3D = $RoadContainer
@onready var _cx_container      : Node3D = $CrossingContainer
@onready var _ped_container     : Node3D = $PedContainer
@onready var _traffic_container : Node3D = $TrafficContainer
@onready var _city_container    : Node3D = $City

@onready var _lbl_score   : Label   = $UI/HUD/ScoreLabel
@onready var _lbl_timer   : Label   = $UI/HUD/TimerLabel
@onready var _lbl_status  : Label   = $UI/HUD/StatusLabel
@onready var _panel_start : Control = $UI/HUD/StartPanel
@onready var _panel_over  : Control = $UI/HUD/GameOverPanel
@onready var _lbl_over    : Label   = $UI/HUD/GameOverPanel/GameOverLabel
@onready var _btn_menu    : Button  = $UI/HUD/GameOverPanel/MenuButton

# ============================================================
# STATE
# ============================================================
enum State     { WAITING, DRIVING, PEDESTRIAN, JUNCTION, SUCCESS, FAILURE, DONE }
enum EventType { CROSSING, JUNCTION }

var _state           : State     = State.WAITING
var _next_event_type : EventType = EventType.CROSSING

var _car_speed    : float = 0.0
var _car_z        : float = 5.0
var _score        : int   = 0
var _time_left    : float = GAME_DURATION
var _result_timer : float = 0.0

var _next_event_z : float = FIRST_EVENT
var _cur_event_z  : float = 0.0
var _event_active : bool  = false
var _event_tile   : Node3D = null

var _peds         : Array[Node3D] = []
var _traffic_cars : Array[Node3D] = []

var _road_pool    : Array[Node3D] = []
var _tile_front_z : float = 0.0

var _bld_r         : Array[Node3D] = []
var _bld_l         : Array[Node3D] = []
var _light_r       : Array[Node3D] = []
var _light_l       : Array[Node3D] = []
var _bld_front_z   : float = 0.0
var _light_front_z : float = 0.0

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	_build_road_pool()
	_build_city_pool()
	_btn_menu.pressed.connect(_go_menu)
	_car_pivot.position.z = _car_z

# ============================================================
# MAIN LOOP
# ============================================================
func _process(delta: float) -> void:
	match _state:
		State.WAITING:
			if Input.is_action_just_pressed("ui_select"):
				_start_game()
			return
		State.DONE:
			return

	# Countdown
	_time_left = maxf(_time_left - delta, 0.0)
	_lbl_timer.text = "Time: %d" % ceili(_time_left)
	if _time_left <= 0.0:
		_end_game()
		return

	# Car always moves — braking slows it, releasing accelerates
	var braking := Input.is_action_pressed("ui_select") or \
		(HCcomm.device_is_connected and HCcomm.button_1)
	if braking:
		_car_speed = maxf(_car_speed - BRAKE * delta, 0.0)
	else:
		_car_speed = minf(_car_speed + ACCEL * delta, CAR_SPEED)
	_car_z += _car_speed * delta
	_car_pivot.position.z = _car_z

	_recycle_road()
	_recycle_city()

	# Result pause — car already moved above, just wait then clear
	if _state == State.SUCCESS or _state == State.FAILURE:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_clear_event()
			_state = State.DRIVING
		return

	# Spawn next event when car is close enough
	if not _event_active and _car_z + 60.0 >= _next_event_z:
		if _next_event_type == EventType.CROSSING:
			_spawn_crossing()
		else:
			_spawn_junction()

	# Active event logic
	match _state:
		State.PEDESTRIAN:
			_check_ped_collision()
			_move_peds(delta)
		State.JUNCTION:
			_move_traffic(delta)
			_check_traffic_collision()
			if _state == State.JUNCTION and _car_z > _cur_event_z + JUNCTION_HALF:
				_trigger_result(true)

# ============================================================
# ROAD POOL
# ============================================================
func _build_road_pool() -> void:
	var packed : PackedScene = load(P_ROAD)
	for i in POOL_SIZE:
		var tile : Node3D = packed.instantiate()
		tile.position = Vector3(0.0, 0.0, float(i) * TILE_SCALE)
		_road_container.add_child(tile)
		_road_pool.append(tile)
	_tile_front_z = float(POOL_SIZE - 1) * TILE_SCALE

func _recycle_road() -> void:
	for tile in _road_pool:
		if tile.position.z < _car_z - TILE_SCALE * 2.0:
			_tile_front_z += TILE_SCALE
			tile.position.z = _tile_front_z

# ============================================================
# CITY POOL
# ============================================================
func _build_city_pool() -> void:
	var bld_packed := [load(P_BLDS[0]), load(P_BLDS[1]), load(P_BLDS[2])]
	var light_packed : PackedScene = load(P_LIGHT)

	for i in BLD_POOL_SIZE:
		var z   : float       = float(i) * BLD_SPACING
		var pck : PackedScene = bld_packed[i % 3]

		var br : Node3D = pck.instantiate()
		br.scale    = Vector3(BLD_SCALE, BLD_SCALE, BLD_SCALE)
		br.position = Vector3(BLD_X_R, 0.0, z)
		_city_container.add_child(br)
		_bld_r.append(br)

		var bl : Node3D = pck.instantiate()
		bl.scale              = Vector3(BLD_SCALE, BLD_SCALE, BLD_SCALE)
		bl.position           = Vector3(BLD_X_L, 0.0, z)
		bl.rotation_degrees.y = 180.0
		_city_container.add_child(bl)
		_bld_l.append(bl)

	_bld_front_z = float(BLD_POOL_SIZE - 1) * BLD_SPACING

	for i in LIGHT_POOL_SIZE:
		var z : float = float(i) * LIGHT_SPACING

		var lr : Node3D = light_packed.instantiate()
		lr.scale    = Vector3(LIGHT_SCALE, LIGHT_SCALE, LIGHT_SCALE)
		lr.position = Vector3(LIGHT_X_R, 0.0, z)
		_city_container.add_child(lr)
		_light_r.append(lr)

		var ll : Node3D = light_packed.instantiate()
		ll.scale              = Vector3(LIGHT_SCALE, LIGHT_SCALE, LIGHT_SCALE)
		ll.position           = Vector3(LIGHT_X_L, 0.0, z)
		ll.rotation_degrees.y = 180.0
		_city_container.add_child(ll)
		_light_l.append(ll)

	_light_front_z = float(LIGHT_POOL_SIZE - 1) * LIGHT_SPACING

func _recycle_city() -> void:
	for i in _bld_r.size():
		if _bld_r[i].position.z < _car_z - BLD_SPACING:
			_bld_front_z += BLD_SPACING
			_bld_r[i].position.z = _bld_front_z
			_bld_l[i].position.z = _bld_front_z

	for i in _light_r.size():
		if _light_r[i].position.z < _car_z - LIGHT_SPACING:
			_light_front_z += LIGHT_SPACING
			_light_r[i].position.z = _light_front_z
			_light_l[i].position.z = _light_front_z

# ============================================================
# CROSSING EVENT
# ============================================================
func _spawn_crossing() -> void:
	_cur_event_z     = _next_event_z
	_next_event_z   += EVENT_GAP
	_next_event_type = EventType.JUNCTION
	_event_active    = true

	_event_tile = load(P_CROSSING).instantiate()
	_event_tile.position = Vector3(0.0, 0.02, _cur_event_z)
	_cx_container.add_child(_event_tile)

	for i in PED_COUNT:
		var ped : Node3D = load(P_CHARS[i % P_CHARS.size()]).instantiate()
		ped.scale              = Vector3(CHAR_SCALE, CHAR_SCALE, CHAR_SCALE)
		ped.position           = Vector3(PED_SIDE_L, 0.0, _cur_event_z + (float(i) - 1.0) * PED_SPREAD)
		ped.rotation_degrees.y = -90.0
		ped.set_meta("done", false)
		_ped_container.add_child(ped)
		_peds.append(ped)
		var tw := create_tween().set_loops()
		tw.tween_property(ped, "position:y", 0.22, 0.28).set_ease(Tween.EASE_OUT)
		tw.tween_property(ped, "position:y", 0.0,  0.28).set_ease(Tween.EASE_IN)

	_state = State.PEDESTRIAN

func _check_ped_collision() -> void:
	for ped in _peds:
		if ped.get_meta("done"):
			continue
		if abs(ped.position.x) < COLL_X_PED and abs(_car_z - ped.position.z) < COLL_Z_PED:
			_trigger_result(false)
			return

func _move_peds(delta: float) -> void:
	var all_done := true
	for ped in _peds:
		if ped.get_meta("done"):
			continue
		all_done = false
		ped.position.x += PED_SPEED * delta
		if ped.position.x >= PED_SIDE_R:
			ped.set_meta("done", true)
	if all_done:
		_trigger_result(true)

# ============================================================
# JUNCTION EVENT
# ============================================================
func _spawn_junction() -> void:
	_cur_event_z     = _next_event_z
	_next_event_z   += EVENT_GAP
	_next_event_type = EventType.CROSSING
	_event_active    = true

	_event_tile = load(P_JUNCTION).instantiate()
	_event_tile.position = Vector3(0.0, 0.02, _cur_event_z)
	_cx_container.add_child(_event_tile)

	# Pre-load all vehicle scenes
	var scenes : Array[PackedScene] = []
	for p in P_TRAFFIC:
		scenes.append(load(p))

	for i in TRAFFIC_COUNT:
		# Left-to-right stream: starts left, faces +X (rotation Y=90)
		var veh_r : Node3D = scenes[i % scenes.size()].instantiate()
		veh_r.scale              = Vector3(TRAFFIC_SCALE, TRAFFIC_SCALE, TRAFFIC_SCALE)
		veh_r.rotation_degrees.y = 90.0
		veh_r.position           = Vector3(-TRAFFIC_X_HALF + float(i) * TRAFFIC_GAP,
										   0.0, _cur_event_z - TRAFFIC_LANE)
		veh_r.set_meta("dir", 1.0)
		_traffic_container.add_child(veh_r)
		_traffic_cars.append(veh_r)

		# Right-to-left stream: starts right, faces -X (rotation Y=-90)
		var veh_l : Node3D = scenes[(i + 3) % scenes.size()].instantiate()
		veh_l.scale              = Vector3(TRAFFIC_SCALE, TRAFFIC_SCALE, TRAFFIC_SCALE)
		veh_l.rotation_degrees.y = -90.0
		veh_l.position           = Vector3(TRAFFIC_X_HALF - float(i) * TRAFFIC_GAP,
										   0.0, _cur_event_z + TRAFFIC_LANE)
		veh_l.set_meta("dir", -1.0)
		_traffic_container.add_child(veh_l)
		_traffic_cars.append(veh_l)

	_state = State.JUNCTION

func _move_traffic(delta: float) -> void:
	for car in _traffic_cars:
		var dir : float = car.get_meta("dir")
		car.position.x += dir * TRAFFIC_SPEED * delta
		# Seamless loop — subtract/add one full period when exiting
		if dir > 0.0 and car.position.x > TRAFFIC_X_HALF:
			car.position.x -= TRAFFIC_LOOP
		elif dir < 0.0 and car.position.x < -TRAFFIC_X_HALF:
			car.position.x += TRAFFIC_LOOP

func _check_traffic_collision() -> void:
	if abs(_car_z - _cur_event_z) > JUNCTION_HALF:
		return   # player not yet inside the junction tile
	for car in _traffic_cars:
		if abs(car.position.x) < COLL_X_TRAFFIC:
			_trigger_result(false)
			return

# ============================================================
# SHARED RESULT / CLEAR
# ============================================================
func _trigger_result(success: bool) -> void:
	if _state == State.SUCCESS or _state == State.FAILURE:
		return
	if success:
		_score += 1
		_lbl_score.text  = "Score: %d" % _score
		_lbl_status.text = "Safe!" if _state == State.PEDESTRIAN else "Junction Clear!"
		_lbl_status.modulate = Color(0.3, 1.0, 0.4)
		_state = State.SUCCESS
	else:
		_lbl_status.text = "Watch Out!" if _state == State.PEDESTRIAN else "Collision!"
		_lbl_status.modulate = Color(1.0, 0.25, 0.25)
		_state = State.FAILURE
	_result_timer = RESULT_PAUSE

func _clear_event() -> void:
	for ped in _peds:
		ped.queue_free()
	_peds.clear()
	for car in _traffic_cars:
		car.queue_free()
	_traffic_cars.clear()
	if is_instance_valid(_event_tile):
		_event_tile.queue_free()
		_event_tile = null
	_event_active        = false
	_lbl_status.text     = ""
	_lbl_status.modulate = Color.WHITE

# ============================================================
# LIFECYCLE
# ============================================================
func _start_game() -> void:
	_panel_start.visible = false
	_clear_event()
	_time_left       = GAME_DURATION
	_score           = 0
	_car_speed       = 0.0
	_car_z           = 5.0
	_next_event_z    = FIRST_EVENT
	_next_event_type = EventType.CROSSING
	_lbl_score.text  = "Score: 0"
	_lbl_timer.text  = "Time: 60"
	_lbl_status.text = ""
	_state = State.DRIVING

func _end_game() -> void:
	_state     = State.DONE
	_car_speed = 0.0
	_lbl_over.text      = "Game Over!\nScore: %d" % _score
	_panel_over.visible = true

# ============================================================
# NAVIGATION
# ============================================================
func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")
