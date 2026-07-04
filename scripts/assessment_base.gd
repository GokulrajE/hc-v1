extends Node

const HOLD_TIME       := 5.0
const HOLD_TIME_STEP2 := 3.0
const HOLDS_REQUIRED  := 5
const TIME_LIMIT      := 60.0

var current_step:                    int   = 1
var hold_timer:                      float = 0.0
var hold_count:                      int   = 0
var hold_completed_in_current_press: bool  = false
var phase_timer:                     float = 0.0

var arc_fill:          float = 0.0
var arc_shake_offset:  float = 0.0
var shaking:           bool  = false
var was_hold_complete: bool  = false

signal hold_just_completed(completed_step: int)
signal step2_hold_registered(count: int)

var _shake_tw: Tween = null


func reset_phase() -> void:
	current_step                    = 1
	hold_timer                      = 0.0
	hold_count                      = 0
	hold_completed_in_current_press = false
	phase_timer                     = 0.0
	arc_fill                        = 0.0
	arc_shake_offset                = 0.0
	was_hold_complete               = false
	stop_shake()


func enter_step2() -> void:
	current_step                    = 2
	hold_timer                      = 0.0
	hold_count                      = 0
	hold_completed_in_current_press = false
	phase_timer                     = 0.0
	arc_fill                        = 0.0
	was_hold_complete               = false
	stop_shake()


func tick(delta: float, is_active: bool) -> void:
	var hold_target := HOLD_TIME if current_step == 1 else HOLD_TIME_STEP2

	if is_active:
		hold_timer += delta
	else:
		hold_timer                      = 0.0
		hold_completed_in_current_press = false

	if current_step == 2:
		phase_timer += delta
		if is_active and hold_timer >= HOLD_TIME_STEP2 and not hold_completed_in_current_press:
			hold_count                     += 1
			hold_completed_in_current_press = true
			step2_hold_registered.emit(hold_count)

	arc_fill = clampf(hold_timer / hold_target, 0.0, 1.0) if is_active else 0.0

	var now_complete := is_active and hold_timer >= hold_target
	if now_complete and not was_hold_complete:
		hold_just_completed.emit(current_step)
		start_shake()
	was_hold_complete = now_complete


func start_shake() -> void:
	if shaking:
		return
	shaking = true
	_do_shake_loop()


func _do_shake_loop() -> void:
	if not shaking:
		arc_shake_offset = 0.0
		return
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	arc_shake_offset = 0.0
	_shake_tw = create_tween()
	for ox: float in [12.0, -12.0, 9.0, -9.0, 6.0, -6.0, 3.0, -3.0, 0.0]:
		_shake_tw.tween_property(self, "arc_shake_offset", ox, 0.055)
	_shake_tw.finished.connect(func(): _do_shake_loop(), CONNECT_ONE_SHOT)


func stop_shake() -> void:
	shaking = false
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	arc_shake_offset = 0.0
