extends Node2D

var knob_1_angle_label: Label
var knob_1_title: Label
var status_label: Label
var back_button: Button
var save_button: Button
var start_button: Button
var stop_button: Button
var redo_button: Button
var min_label: Label
var max_label: Label
var current_label: Label
var reaching_timer_label: Label

var knob_gauge: KnobGauge

var min_angle    = 0.0
var max_angle    = 0.0
var current_angle = 0.0
var selected_knob = ""
var current_mechanism = null

const STEP1_MIN_LIMIT = 10.0
const STEP1_MAX_LIMIT = 10.0

enum AssessmentStep { STEP1_VALIDATION, STEP2_AROM, STEP3_REACHING }
var current_step = AssessmentStep.STEP1_VALIDATION
var step1_crossed_min = false
var step1_crossed_max = false

var arom_min = 0.0
var arom_max = 0.0

var reaching_timer = 0.0
var reach_count = 0
var last_reached_min = false
var last_reached_max = false
var step3_complete = false
const REACHING_TIME_LIMIT = 60.0
const REQUIRED_REACHES = 5

var step3_flash_timer: float = 0.0
var step3_flash_color: Color

const COL_AROM_PURPLE := Color(0.42, 0.14, 0.61, 1.0)
const COL_FLASH_MIN   := Color(0.3,  0.7,  1.0,  1.0)
const COL_FLASH_MAX   := Color(0.2,  0.95, 0.4,  1.0)


func _ready() -> void:
	knob_1_title       = get_node_or_null("knob_1_title")
	knob_1_angle_label = get_node_or_null("knob_1_angle_label")
	status_label       = get_node_or_null("status_label")
	back_button        = get_node_or_null("back_button")
	save_button        = get_node_or_null("save_button")
	start_button       = get_node_or_null("start_button")
	stop_button        = get_node_or_null("stop_button")
	redo_button        = get_node_or_null("redo_button")

	min_label            = get_node_or_null("min_max_container/min_label")
	max_label            = get_node_or_null("min_max_container/max_label")
	current_label        = get_node_or_null("min_max_container/current_label")
	reaching_timer_label = get_node_or_null("reaching_timer_display")

	knob_gauge = get_node_or_null("knob_gauge")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.visible = false
	if stop_button:
		stop_button.pressed.connect(_on_stop_pressed)
		stop_button.visible = false
	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)
		redo_button.visible = false

	if HCcomm:
		if HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
			HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
		HCcomm.new_device_data.connect(_on_device_data_received)

	selected_knob = Appdata.selected_mechanism.name
	print("KnobAssessment: selected — %s" % selected_knob)
	_start_arom_raw_logging()
	_update_title()
	_update_step1_display()


# ── Title / angle helpers ─────────────────────────────────────────────────────

func _update_title() -> void:
	if knob_1_title:
		knob_1_title.text = selected_knob


func _get_current_angle() -> float:
	match selected_knob:
		"KNOB":      return HCcomm.angle_2
		"FINE KNOB": return HCcomm.angle_4
		"KEY KNOB":  return HCcomm.angle_3
		_:           return 0.0


# ── Device data handler ───────────────────────────────────────────────────────

func _on_device_data_received() -> void:
	current_angle = _get_current_angle()

	if knob_1_angle_label:
		knob_1_angle_label.text = "%.2f°" % current_angle
	if current_label:
		current_label.text = "Current: %.2f°" % current_angle
	if knob_gauge:
		knob_gauge.set_current_angle(current_angle)

	match current_step:
		AssessmentStep.STEP1_VALIDATION: _process_step1()
		AssessmentStep.STEP2_AROM:       _process_step2()
		AssessmentStep.STEP3_REACHING:   _process_step3()


# ── Step 1 ────────────────────────────────────────────────────────────────────

func _update_step1_display() -> void:
	if min_label:  min_label.text = "Min Limit: -%.2f°" % STEP1_MIN_LIMIT
	if max_label:  max_label.text = "Max Limit: %.2f°"  % STEP1_MAX_LIMIT
	if status_label:
		status_label.text = "STEP 1: Validation — Cross both limits to proceed"
	if knob_gauge:
		knob_gauge.set_display_range(-10.0, 10.0)
		knob_gauge.clear_shade_zone()
		knob_gauge.set_track(true, Color(1.0, 0.85, 0.0, 0.6))
		knob_gauge.set_range_label_color(Color(1.0, 0.85, 0.0, 1.0))


func _process_step1() -> void:
	min_angle = STEP1_MIN_LIMIT
	max_angle = STEP1_MAX_LIMIT
	if current_angle < -STEP1_MIN_LIMIT: step1_crossed_min = true
	if current_angle >  STEP1_MAX_LIMIT: step1_crossed_max = true
	if step1_crossed_min and step1_crossed_max:
		if knob_gauge:
			knob_gauge.set_track(true, Color(0.2, 0.95, 0.4, 0.7))
			knob_gauge.set_range_label_color(Color(0.2, 0.95, 0.4, 1.0))
		_complete_step1()


func _complete_step1() -> void:
	if status_label:
		status_label.text = "✓ Step 1 Complete! Click START to begin AROM Assessment"
	if start_button:
		start_button.visible = true
	min_angle = 0.0
	max_angle = 0.0
	print("KnobAssessment: Step 1 passed")


# ── Step 2 ────────────────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if start_button: start_button.visible = false
	if stop_button:  stop_button.visible  = true
	if redo_button:  redo_button.visible  = true
	min_angle = 0.0
	max_angle = 0.0
	current_step = AssessmentStep.STEP2_AROM
	if status_label:
		status_label.text = "STEP 2: AROM — Move knob through full range, then STOP or REDO"
	if knob_gauge:
		knob_gauge.set_track(false)
		knob_gauge.clear_shade_zone()
		knob_gauge.set_range_label_color(Color(0.65, 0.65, 0.65, 1.0))
	print("KnobAssessment: Step 2 started")


func _process_step2() -> void:
	if current_angle < min_angle: min_angle = current_angle
	if current_angle > max_angle: max_angle = current_angle
	if min_label: min_label.text = "Min: %.2f°" % min_angle
	if max_label: max_label.text = "Max: %.2f°" % max_angle
	if knob_gauge and min_angle < max_angle:
		knob_gauge.set_display_range(min_angle, max_angle)
		knob_gauge.set_shade_zone(min_angle, max_angle, COL_AROM_PURPLE)


func _on_stop_pressed() -> void:
	if stop_button: stop_button.visible = false
	_advance_to_step3()


func _on_redo_pressed() -> void:
	min_angle = current_angle
	max_angle = current_angle
	if status_label:
		status_label.text = "STEP 2: AROM — Move knob through full range, then STOP or REDO"
	if min_label: min_label.text = "Min: 0.00°"
	if max_label: max_label.text = "Max: 0.00°"
	if knob_gauge:
		knob_gauge.set_track(false)
		knob_gauge.set_display_range(-10.0, 10.0)
		knob_gauge.clear_shade_zone()
	print("KnobAssessment: AROM redo")


# ── Step 3 ────────────────────────────────────────────────────────────────────

func _advance_to_step3() -> void:
	current_step     = AssessmentStep.STEP3_REACHING
	arom_min         = min_angle
	arom_max         = max_angle
	reaching_timer   = 0.0
	reach_count      = 0
	last_reached_min = false
	last_reached_max = false

	if stop_button:  stop_button.visible = false
	if redo_button:  redo_button.visible = false
	if status_label:
		status_label.text = "STEP 3: Reach min/max 5 times in 60 seconds"
	if min_label: min_label.text = "AROM Min: %.2f°" % arom_min
	if max_label: max_label.text = "AROM Max: %.2f°" % arom_max

	step3_flash_timer = 0.0
	if knob_gauge:
		knob_gauge.set_display_range(arom_min, arom_max)
		knob_gauge.set_track(false)
		knob_gauge.set_shade_zone(arom_min, arom_max, COL_AROM_PURPLE)
		knob_gauge.activate_step3(arom_min, arom_max, false, 1)

	print("KnobAssessment: Step 2 done — AROM %.2f° to %.2f°" % [arom_min, arom_max])


func _process_step3() -> void:
	if step3_complete:
		return

	if current_angle <= arom_min and not last_reached_min:
		last_reached_min = true
		last_reached_max = false
		step3_flash_timer = 0.4
		step3_flash_color = COL_FLASH_MIN
		if knob_gauge:
			knob_gauge.set_shade_zone(arom_min, arom_max, COL_FLASH_MIN)
	elif current_angle >= arom_max and last_reached_min and not last_reached_max:
		last_reached_max = true
		last_reached_min = false
		reach_count += 1
		step3_flash_timer = 0.4
		step3_flash_color = COL_FLASH_MAX
		if knob_gauge:
			knob_gauge.set_shade_zone(arom_min, arom_max, COL_FLASH_MAX)

	if current_label:
		current_label.text = "Reaches: %d/%d | Time: %.1f s" % [reach_count, REQUIRED_REACHES, reaching_timer]

	var going_to_max: bool = last_reached_min
	if knob_gauge:
		knob_gauge.update_step3(going_to_max, reach_count + 1)

	if reach_count >= REQUIRED_REACHES or reaching_timer >= REACHING_TIME_LIMIT:
		_complete_step3()


func _complete_step3() -> void:
	step3_complete = true
	if status_label:
		if reach_count >= REQUIRED_REACHES and reaching_timer <= REACHING_TIME_LIMIT:
			status_label.text = "✓ Done! %d reaches in %.1f s — Click SAVE" % [reach_count, reaching_timer]
		else:
			status_label.text = "Time expired. %d/%d reaches — Click SAVE" % [reach_count, REQUIRED_REACHES]
	if save_button:
		save_button.visible = true

	if knob_gauge:
		knob_gauge.clear_step3()

	print("KnobAssessment: Step 3 done — %d reaches in %.1f s" % [reach_count, reaching_timer])


# ── Physics process (timers) ──────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	var dt := get_physics_process_delta_time()

	if current_step == AssessmentStep.STEP3_REACHING and not step3_complete:
		reaching_timer += dt
		if reaching_timer_label:
			reaching_timer_label.text = "Time: %d s" % int(reaching_timer)
		if status_label:
			status_label.text = "Reaches: %d/%d | Time: %d/60 s" % [reach_count, REQUIRED_REACHES, int(reaching_timer)]

	if step3_flash_timer > 0.0:
		step3_flash_timer -= dt
		if step3_flash_timer <= 0.0 and knob_gauge:
			knob_gauge.set_shade_zone(arom_min, arom_max, COL_AROM_PURPLE)


# ── Save / navigation ─────────────────────────────────────────────────────────

func _start_arom_raw_logging() -> void:
	AppDataTrial.start_arom_raw_data_logging()
	print("KnobAssessment: AROM logging started for %s" % Appdata.selected_mechanism.name)


func _on_save_pressed() -> void:
	if Appdata.selected_mechanism == null:
		push_error("KnobAssessment: no mechanism")
		if status_label: status_label.text = "Error: Mechanism not initialised."
		return

	AppDataTrial.stop_arom_raw_data_logging()
	Appdata.selected_mechanism.set_new_arom_values(arom_min, arom_max, float(int(reaching_timer)))

	if Appdata.selected_mechanism.save_assessment_data():
		if status_label:
			status_label.text = "✓ Saved! AROM: %.2f° to %.2f° | %d reaches in %d s" % \
				[arom_min, arom_max, reach_count, int(reaching_timer)]
		print("KnobAssessment: saved %s — %.2f° to %.2f°" % [selected_knob, arom_min, arom_max])
		_cleanup()
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/safecrossing/sc_game.tscn")
	else:
		if status_label: status_label.text = "Error: failed to save."
		push_error("KnobAssessment: save failed for %s" % selected_knob)


func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")


func _cleanup() -> void:
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))


func _exit_tree() -> void:
	_cleanup()
