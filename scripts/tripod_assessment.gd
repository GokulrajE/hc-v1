extends Node2D

var status_label: Label
var distance_label: Label
var back_button: Button
var save_button: Button
var setmin_button: Button
var setmax_button: Button
var start_button: Button
var minprogressbar1: ProgressBar
var minprogressbar2: ProgressBar
var maxprogressbar1: ProgressBar
var maxprogressbar2: ProgressBar
var reach_count_label: Label
var reaching_timer_label: Label
var min_ind_left:   Control = null
var min_ind_right:  Control = null
var max_ind_left:   Control = null
var max_ind_right:  Control = null
var _mm_container:  Control = null
var _min_val_label: Label   = null
var _max_val_label: Label   = null
var _cur_val_label: Label   = null
var _arrow_col_min: Color   = Color(1.0, 0.9, 0.0, 1.0)
var _arrow_col_max: Color   = Color(1.0, 0.9, 0.0, 1.0)
var _min_row_ind:   Control = null
var _max_row_ind:   Control = null
const FLASH_COL_MIN: Color  = Color(0.15, 1.0, 0.45, 1.0)
const FLASH_COL_MAX: Color  = Color(0.0,  0.82, 1.0, 1.0)

var distance_current: float = 6.0
var distance_start: float = 6.0
var distance_min: float = 6.0
var distance_max: float = 6.0
var flash_timer: float = 0.0
var pulse_time: float = 0.0

# Moving average for sensor noise reduction
var moving_average: float = 0.0
var moving_average_counter: int = 0
const MOVING_AVERAGE_LENGTH: int = 10

# Tripod assessment states
enum AssessmentStep { SETMAX, SETMIN, REACHING, COMPLETE }
var current_step = AssessmentStep.SETMAX

# Reaching validation
var reaching_timer: float = 0.0
var reach_count: int = 1
var last_reached_min: bool = false
var last_reached_max: bool = false
var step_reaching_complete: bool = false

const MIN_DISTANCE = 2.0
const MAX_DISTANCE = 6.0
const REACHING_TIME_LIMIT = 60.0
const REQUIRED_REACHES = 5
const NEAR_THRESHOLD = 0.2

func _ready() -> void:
	status_label = get_node_or_null("status_label")
	distance_label = get_node_or_null("distance_label")
	back_button = get_node_or_null("back_button")
	save_button = get_node_or_null("save_button")
	setmin_button = get_node_or_null("setmin_button")
	setmax_button = get_node_or_null("setmax_button")
	start_button = get_node_or_null("start_button")
	minprogressbar1 = get_node_or_null("minProgressBarE-B/minProgressBarB-E")
	minprogressbar2 = get_node_or_null("minProgressBarE-B")
	maxprogressbar1 = get_node_or_null("maxProgressBarE-B2/maxProgressBarB-E")
	maxprogressbar2 = get_node_or_null("maxProgressBarE-B2")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	if setmax_button:
		setmax_button.pressed.connect(_on_setmax_pressed)
		setmax_button.visible = true

	if setmin_button:
		setmin_button.pressed.connect(_on_setmin_pressed)
		setmin_button.visible = false

	if start_button:
		start_button.pressed.connect(_on_start_reaching_pressed)
		start_button.visible = false

	if HCcomm:
		# Disconnect if already connected to prevent duplicate signal error
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)

	reach_count_label = get_node_or_null("timer_label")
	reaching_timer_label = get_node_or_null("reaching_timer_display")
	_mm_container  = get_node_or_null("min_max_container")
	_min_val_label = get_node_or_null("min_max_container/min_label")
	_max_val_label = get_node_or_null("min_max_container/max_label")
	_cur_val_label = get_node_or_null("min_max_container/current_label")

	print("TripodAssessment: Started for Tripod Grip mechanism")
	_reset_moving_average()
	_start_arom_raw_logging()
	_update_display()

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	var dt = get_physics_process_delta_time()
	if current_step == AssessmentStep.REACHING:
		if not step_reaching_complete:
			reaching_timer += dt
		pulse_time += dt

		if reach_count_label:
			reach_count_label.text = "%d" % reach_count

		if reaching_timer_label:
			reaching_timer_label.text = "Time: %d s" % int(reaching_timer)

		if status_label:
			status_label.text = "Reaches: %d/%d | Time: %d/60 s" % [reach_count, REQUIRED_REACHES, int(reaching_timer)]

	# Flash decay
	if flash_timer > 0.0:
		flash_timer -= dt

func _on_device_data_received() -> void:
	var raw_distance = HCcomm.get_btw_distance()
	distance_current = _calculate_moving_average(raw_distance)

	match current_step:
		AssessmentStep.SETMAX:
			_update_max_bars()
		AssessmentStep.SETMIN:
			_update_min_bars()
		AssessmentStep.REACHING:
			_process_reaching()

	if distance_label:
		distance_label.text = "Distance: %.2f cm" % distance_current

func _update_min_bars() -> void:
	# Track minimum distance during compression phase
	if !setmin_button.visible:
		_update_reaching_bars()
		return  # Don't update min bars until we're in the setmin phase
	if distance_current < distance_min:
		distance_min = distance_current

	# Update min progress bars
	if minprogressbar1:
		minprogressbar1.value = distance_current
		minprogressbar1.modulate = Color(1, 1, 1, 1)
	if minprogressbar2:
		minprogressbar2.value = distance_current
		minprogressbar2.modulate = Color(1, 1, 1, 1)

func _update_max_bars() -> void:
	# Track maximum distance during recovery phase
	if distance_current > distance_max:
		distance_max = distance_current

	# Update max progress bars
	if maxprogressbar1:
		maxprogressbar1.value = distance_current
		maxprogressbar1.modulate = Color(1, 1, 1, 1)
	if maxprogressbar2:
		maxprogressbar2.value = distance_current
		maxprogressbar2.modulate = Color(1, 1, 1, 1)

func _update_reaching_bars() -> void:
	if minprogressbar1: minprogressbar1.value = distance_min
	if minprogressbar2: minprogressbar2.value = distance_min
	if maxprogressbar1: maxprogressbar1.value = distance_max
	if maxprogressbar2: maxprogressbar2.value = distance_max
	if _cur_val_label:
		_cur_val_label.text = "Now: %.2f cm" % distance_current
	var at_min := distance_current <= distance_min + NEAR_THRESHOLD
	var at_max := distance_current >= distance_max - NEAR_THRESHOLD
	_arrow_col_min = FLASH_COL_MIN if at_min else Color(1.0, 0.9, 0.0, 1.0)
	_arrow_col_max = FLASH_COL_MAX if at_max else Color(1.0, 0.9, 0.0, 1.0)
	if min_ind_left  and minprogressbar2: _update_ind(min_ind_left,  minprogressbar2, distance_current, distance_min, _arrow_col_min, pulse_time, flash_timer)
	if min_ind_right and minprogressbar1: _update_ind(min_ind_right, minprogressbar1, distance_current, distance_min, _arrow_col_min, pulse_time, flash_timer)
	if max_ind_left  and maxprogressbar2: _update_ind(max_ind_left,  maxprogressbar2, distance_current, distance_max, _arrow_col_max, pulse_time, flash_timer)
	if max_ind_right and maxprogressbar1: _update_ind(max_ind_right, maxprogressbar1, distance_current, distance_max, _arrow_col_max, pulse_time, flash_timer)
	_update_row_arrows()

func _update_row_arrows() -> void:
	var next_is_min: bool = last_reached_max
	var at_min: bool = distance_current <= distance_min + NEAR_THRESHOLD
	var at_max: bool = distance_current >= distance_max - NEAR_THRESHOLD
	var col: Color = FLASH_COL_MIN if next_is_min else Color(1.0, 0.82, 0.0, 1.0)
	if _min_row_ind and minprogressbar2 and minprogressbar1:
		_update_row_ind(_min_row_ind, minprogressbar2, minprogressbar1, next_is_min, col, at_min, at_max)
	if _max_row_ind and maxprogressbar2 and maxprogressbar1:
		_update_row_ind(_max_row_ind, maxprogressbar2, maxprogressbar1, next_is_min, col, at_min, at_max)

func _update_row_ind(overlay: Control, left_pb: ProgressBar, right_pb: ProgressBar, next_is_min: bool, col: Color, at_min: bool, at_max: bool) -> void:
	var br: float = float(left_pb.max_value) - float(left_pb.min_value)
	if br <= 0.0: return
	var min_pct: float = clamp((distance_min - float(left_pb.min_value)) / br, 0.0, 1.0)
	var max_pct: float = clamp((distance_max - float(left_pb.min_value)) / br, 0.0, 1.0)
	var x0: float    = left_pb.global_position.x
	var x_mid: float = right_pb.global_position.x
	var x1: float    = right_pb.global_position.x + right_pb.size.x
	var lw: float = x_mid - x0
	var rw: float = x1 - x_mid
	var lmin_x: float = (1.0 - min_pct) * lw
	var lmax_x: float = (1.0 - max_pct) * lw
	var rmin_x: float = lw + min_pct * rw
	var rmax_x: float = lw + max_pct * rw
	overlay.global_position = Vector2(x0, left_pb.global_position.y - 54.0)
	overlay.size = Vector2(x1 - x0, 54.0)
	overlay.set_meta("lmin_x", lmin_x)
	overlay.set_meta("lmax_x", lmax_x)
	overlay.set_meta("rmin_x", rmin_x)
	overlay.set_meta("rmax_x", rmax_x)
	overlay.set_meta("col",    col)
	overlay.set_meta("nim",    next_is_min)
	overlay.set_meta("pt",     pulse_time)
	overlay.set_meta("ft",     flash_timer)
	overlay.set_meta("at_min", at_min)
	overlay.set_meta("at_max", at_max)
	overlay.queue_redraw()
	if not overlay.get_meta("row_conn", false):
		overlay.draw.connect(_on_draw_row_ind.bind(overlay))
		overlay.set_meta("row_conn", true)

func _on_draw_row_ind(overlay: Control) -> void:
	var lmin_x: float = overlay.get_meta("lmin_x", 0.0)
	var lmax_x: float = overlay.get_meta("lmax_x", 0.0)
	var rmin_x: float = overlay.get_meta("rmin_x", 0.0)
	var rmax_x: float = overlay.get_meta("rmax_x", 0.0)
	var col:    Color = overlay.get_meta("col",    Color(1.0, 0.82, 0.0, 1.0))
	var nim:    bool  = overlay.get_meta("nim",    false)
	var pt:     float = overlay.get_meta("pt",     0.0)
	var ft:     float = overlay.get_meta("ft",     0.0)
	var at_min: bool  = overlay.get_meta("at_min", false)
	var at_max: bool  = overlay.get_meta("at_max", false)
	var cy:      float = 20.0
	var lcx:     float = (lmin_x + lmax_x) * 0.5
	var rcx:     float = (rmin_x + rmax_x) * 0.5
	var pulse:   float = 0.5 + 0.5 * sin(pt * 5.5)
	var lw:      float = 2.0 + 1.0 * pulse
	var hs:      float = 18.0 + 6.0 * pulse
	var tail:    float = 30.0
	var flash_t: float = ft / 0.3 if ft > 0.0 else 0.0
	var glow:    Color = Color(col.r, col.g, col.b, 0.22)

	# Left bar is RTL so its directions are mirrored vs the right bar
	_draw_centered_arrow(overlay, lcx, cy, not nim, col, glow, lw, hs, tail)
	_draw_centered_arrow(overlay, rcx, cy, nim,     col, glow, lw, hs, tail)

	if ft > 0.0:
		var ring_r: float = 18.0 + (1.0 - flash_t) * 20.0
		var rc: Color = Color(col.r, col.g, col.b, flash_t)
		if nim and at_min:
			# left bar points right → tip is at lcx + tail; right bar points left → tip at rcx - tail
			overlay.draw_arc(Vector2(lcx + tail, cy), ring_r, 0.0, TAU, 28, rc, 4.0)
			overlay.draw_arc(Vector2(rcx - tail, cy), ring_r, 0.0, TAU, 28, rc, 4.0)
		elif not nim and at_max:
			# left bar points left → tip at lcx - tail; right bar points right → tip at rcx + tail
			overlay.draw_arc(Vector2(lcx - tail, cy), ring_r, 0.0, TAU, 28, rc, 4.0)
			overlay.draw_arc(Vector2(rcx + tail, cy), ring_r, 0.0, TAU, 28, rc, 4.0)


func _draw_centered_arrow(overlay: Control, cx: float, cy: float, point_left: bool, col: Color, glow: Color, lw: float, hs: float, tail: float) -> void:
	if point_left:
		var tip_x  := cx - tail
		var tail_x := cx + tail
		overlay.draw_line(Vector2(tail_x, cy), Vector2(tip_x + hs, cy), glow, lw + 10.0)
		overlay.draw_line(Vector2(tail_x, cy), Vector2(tip_x + hs, cy), col, lw)
		overlay.draw_colored_polygon(PackedVector2Array([
			Vector2(tip_x, cy), Vector2(tip_x + hs, cy - hs * 0.75), Vector2(tip_x + hs, cy + hs * 0.75)
		]), col)
	else:
		var tip_x  := cx + tail
		var tail_x := cx - tail
		overlay.draw_line(Vector2(tail_x, cy), Vector2(tip_x - hs, cy), glow, lw + 10.0)
		overlay.draw_line(Vector2(tail_x, cy), Vector2(tip_x - hs, cy), col, lw)
		overlay.draw_colored_polygon(PackedVector2Array([
			Vector2(tip_x, cy), Vector2(tip_x - hs, cy - hs * 0.75), Vector2(tip_x - hs, cy + hs * 0.75)
		]), col)

func _update_ind(overlay: Control, pb: ProgressBar, cur_val: float, tgt_val: float, col: Color, pt: float = 0.0, ft: float = 0.0) -> void:
	var br: float = float(pb.max_value) - float(pb.min_value)
	var cur_pct: float = clamp((cur_val - float(pb.min_value)) / br, 0.0, 1.0) if br > 0.0 else 0.0
	var tgt_pct: float = clamp((tgt_val - float(pb.min_value)) / br, 0.0, 1.0) if br > 0.0 else 0.0
	overlay.global_position = pb.global_position + Vector2(0.0, -30.0)
	overlay.size = Vector2(pb.size.x, pb.size.y + 30.0)
	var cur_ix: float = clamp(((1.0 - cur_pct) if pb.fill_mode == 1 else cur_pct) * pb.size.x, 0.0, pb.size.x)
	var tgt_ix: float = clamp(((1.0 - tgt_pct) if pb.fill_mode == 1 else tgt_pct) * pb.size.x, 0.0, pb.size.x)
	overlay.set_meta("cur_ix", cur_ix)
	overlay.set_meta("tgt_ix", tgt_ix)
	overlay.set_meta("bh",     pb.size.y)
	overlay.set_meta("col",    col)
	overlay.set_meta("pt",     pt)
	overlay.set_meta("ft",     ft)
	overlay.queue_redraw()
	if not overlay.get_meta("connected", false):
		overlay.draw.connect(_on_draw_ind.bind(overlay))
		overlay.set_meta("connected", true)

func _on_draw_ind(overlay: Control) -> void:
	var cur_x: float = overlay.get_meta("cur_ix", 0.0)
	var tgt_x: float = overlay.get_meta("tgt_ix", 0.0)
	var bh:    float = overlay.get_meta("bh",    58.0)
	var col:   Color = overlay.get_meta("col",   Color(1.0, 0.9, 0.0, 1.0))
	var pt:    float = overlay.get_meta("pt",    0.0)
	var ft:    float = overlay.get_meta("ft",    0.0)
	var pulse: float = 0.5 + 0.5 * sin(pt * 5.5)
	var flash_s: float = 1.0 + ft * 0.9

	# Target arrow: glow + solid white
	var tgt_col := Color(0.92, 0.92, 0.92, 0.78)
	overlay.draw_colored_polygon(PackedVector2Array([
		Vector2(tgt_x - 15.0, 0.0), Vector2(tgt_x + 15.0, 0.0), Vector2(tgt_x, 32.0)
	]), Color(1.0, 1.0, 1.0, 0.18))
	overlay.draw_colored_polygon(PackedVector2Array([
		Vector2(tgt_x - 10.0, 0.0), Vector2(tgt_x + 10.0, 0.0), Vector2(tgt_x, 24.0)
	]), tgt_col)
	overlay.draw_line(Vector2(tgt_x, 23.0), Vector2(tgt_x, 30.0 + bh), tgt_col, 3.0)

	# Current arrow: glow layer + pulsing solid + stem
	var hs: float = (11.0 + 3.5 * pulse) * flash_s
	overlay.draw_colored_polygon(PackedVector2Array([
		Vector2(cur_x - hs * 1.6, 0.0), Vector2(cur_x + hs * 1.6, 0.0), Vector2(cur_x, hs * 1.6)
	]), Color(col.r, col.g, col.b, 0.22))
	overlay.draw_colored_polygon(PackedVector2Array([
		Vector2(cur_x - hs, 0.0), Vector2(cur_x + hs, 0.0), Vector2(cur_x, hs * 1.15)
	]), col)
	overlay.draw_line(Vector2(cur_x, hs - 1.0), Vector2(cur_x, 30.0 + bh), col, 4.0)

	# Flash ring when touching target
	if ft > 0.0:
		var ring_r: float = 14.0 + (1.0 - ft / 0.3) * 16.0
		overlay.draw_arc(Vector2(cur_x, hs * 0.5), ring_r, 0.0, TAU, 24, Color(col.r, col.g, col.b, ft / 0.3), 3.0)

func _calculate_moving_average(raw_value: float) -> float:
	moving_average_counter += 1

	if moving_average_counter > MOVING_AVERAGE_LENGTH:
		moving_average = moving_average + (raw_value - moving_average) / (MOVING_AVERAGE_LENGTH + 1)
	else:
		moving_average += raw_value
		if moving_average_counter == MOVING_AVERAGE_LENGTH:
			moving_average = moving_average / moving_average_counter

	return moving_average

func _reset_moving_average() -> void:
	moving_average = 0.0
	moving_average_counter = 0

func _update_display() -> void:
	if status_label:
		match current_step:
			AssessmentStep.SETMAX:
				status_label.text = "STEP 1: Release and expand to find maximum extension distance, then click SET MAX"
			AssessmentStep.SETMIN:
				if start_button and start_button.visible:
					status_label.text = "Ready to start reaching validation. Click CONTINUE to begin"
				else:
					status_label.text = "STEP 2: Squeeze the tripod grip to find minimum compression distance, then click SET MIN"
			AssessmentStep.REACHING:
				status_label.text = "STEP 3: Reaching Validation - Touch min/max 5 times in 60 seconds"
			AssessmentStep.COMPLETE:
				status_label.text = "✓ Assessment complete! Click SAVE ASSESSMENT to store results"

func _on_setmax_pressed() -> void:
	
	distance_max = distance_current
	current_step = AssessmentStep.SETMIN
	setmax_button.visible = false
	setmin_button.visible = true
	_reset_moving_average()
	_update_display()
	print("TripodAssessment: Maximum distance set to %.2f cm - Now finding minimum" % [distance_max])

func _on_setmin_pressed() -> void:
	
	distance_min = distance_current
	setmin_button.visible = false
	if start_button:
		start_button.visible = true
		start_button.text = "Continue"
	_advance_to_reaching()
	print("TripodAssessment: Minimum distance set to %.2f cm - Ready to start reaching validation" % [distance_min])

func _on_start_reaching_pressed() -> void:
	ScAudioManager.play_asmnt_btn()
	if start_button:
		start_button.visible = false
	current_step = AssessmentStep.REACHING
	_create_indicator_lines()
	_update_display()
	print("TripodAssessment: Starting reaching validation phase")

func _advance_to_reaching() -> void:
	
	reaching_timer = 0.0
	reach_count = 0
	last_reached_min = false
	last_reached_max = false
	pulse_time = 0.0
	step_reaching_complete = false
	_reset_moving_average()

	if reach_count_label:
		reach_count_label.visible = true
		reach_count_label.z_index = 100
		reach_count_label.text = "%d" % reach_count
		reach_count_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))

	_update_display()
	print("TripodAssessment: Advancing to Step 3 - Reaching Validation. Range: %.2f - %.2f cm. Time limit: %.2f s" % [distance_min, distance_max, REACHING_TIME_LIMIT])

func _create_indicator_lines() -> void:
	min_ind_left  = _make_ind_overlay()
	min_ind_right = _make_ind_overlay()
	max_ind_left  = _make_ind_overlay()
	max_ind_right = _make_ind_overlay()
	_min_row_ind  = _make_ind_overlay()
	_max_row_ind  = _make_ind_overlay()
	if _mm_container:
		_mm_container.visible = true
		if _min_val_label: _min_val_label.text = "Min: %.2f cm" % distance_min
		if _max_val_label: _max_val_label.text = "Max: %.2f cm" % distance_max

func _make_ind_overlay() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _process_reaching() -> void:
	if step_reaching_complete:
		return

	var at_min = distance_current <= distance_min + NEAR_THRESHOLD
	var at_max = distance_current >= distance_max - NEAR_THRESHOLD

	if at_min and not last_reached_min:
		last_reached_min = true
		if last_reached_max:
			reach_count += 1
		last_reached_max = false
		flash_timer = 0.3
		ScAudioManager.play_asmnt_reach()
	elif at_max and not last_reached_max:
		last_reached_max = true
		last_reached_min = false
		flash_timer = 0.3
		ScAudioManager.play_asmnt_reach()

	_update_reaching_bars()

	if reach_count >= REQUIRED_REACHES:
		_complete_reaching()
	elif reaching_timer >= REACHING_TIME_LIMIT:
		_complete_reaching()

func _complete_reaching() -> void:
	step_reaching_complete = true
	current_step = AssessmentStep.COMPLETE
	ScAudioManager.play_asmnt_complete()

	if status_label:
		if reach_count >= REQUIRED_REACHES and reaching_timer <= REACHING_TIME_LIMIT:
			status_label.text = "✓ Reaching Complete! Reaches: %d in %.1f seconds - Click SAVE" % [reach_count, reaching_timer]
		else:
			status_label.text = "Time expired. Reaches: %d/%d - Click SAVE to submit" % [reach_count, REQUIRED_REACHES]

	if save_button:
		save_button.visible = true
	if reach_count_label:
		reach_count_label.visible = false

	# Clean up indicator overlays
	for ovl in [min_ind_left, min_ind_right, max_ind_left, max_ind_right, _min_row_ind, _max_row_ind]:
		if ovl: ovl.queue_free()
	min_ind_left = null; min_ind_right = null
	max_ind_left = null; max_ind_right = null
	_min_row_ind = null; _max_row_ind = null
	if _mm_container: _mm_container.visible = false

	_update_display()
	print("TripodAssessment: Step 3 complete! Reaches: %d in %.2f seconds" % [reach_count, reaching_timer])

func _start_arom_raw_logging() -> void:
	AppDataTrial.start_arom_raw_data_logging()
	print("TripodAssessment: Started AROM raw data logging for Tripod Grip")

func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("TripodAssessment: Mechanism not initialized")
		if status_label:
			status_label.text = "Error: Mechanism not initialized. Cannot save."
		return

	# Stop AROM raw data logging
	AppDataTrial.stop_arom_raw_data_logging()

	# Set AROM values: min = minimum distance (compression), max = maximum distance (relaxed)
	Appdata.selected_mechanism.set_new_arom_values(distance_min, distance_max, float(int(reaching_timer)))

	# Save assessment data
	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Success! Distance: %.2f-%.2f cm | Reaches: %d/5 | Time: %d s" % [distance_min, distance_max, reach_count, int(reaching_timer)]
		print("TripodAssessment: Assessment saved successfully for Tripod Grip - Distance: %.2f-%.2f cm, Reaches: %d, Time: %d s" % [distance_min, distance_max, reach_count, int(reaching_timer)])
		print("🎮 Assessment done — opening Game Selection...")
		_cleanup()
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
	else:
		if status_label:
			status_label.text = "Error: Failed to save assessment data."
		push_error("TripodAssessment: Failed to save assessment data for Tripod Grip")

func _on_back_pressed() -> void:
	_cleanup()
	if Appdata.reassessing:
		Appdata.reassessing = false
		get_tree().change_scene_to_file("res://scene/game_selection.tscn")
		return
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")

func _cleanup() -> void:
	# Disconnect from signals to prevent errors when re-entering scene
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))

func _exit_tree() -> void:
	_cleanup()
