extends Node2D

# ── node refs ─────────────────────────────────────────────────────────────────
var back_button:      Button   = null
var save_button:      Button   = null
var circleIndication: Sprite2D = null
var _hint_lbl:        Label    = null
var _arc_layer:       Node2D   = null

# ── card nodes ────────────────────────────────────────────────────────────────
var _card_bg:            Panel     = null
var _card_name_lbl:      Label     = null
var _card_check:         Label     = null
var _card_step_lbl:      Label     = null
var _card_timer_lbl:     Label     = null
var _card_prog_fill:     Control   = null
var _card_step_a:        ColorRect = null
var _card_step_b:        ColorRect = null
var _card_continue_btn:  Button    = null
var _card_incapable_btn: Button    = null

# ── warning panel ─────────────────────────────────────────────────────────────
var _warning_panel:      Control = null
var _warning_msg_lbl:    Label   = null
var _warning_ok_btn:     Button  = null
var _warning_cancel_btn: Button  = null

# ── constants ─────────────────────────────────────────────────────────────────
const PROG_FILL_W := 470.0
const PHASE_COLOR := Color(1.0, 0.6, 0.0)

# ── assessment state ──────────────────────────────────────────────────────────
var buttons_step1_complete:       bool  = false
var buttons_step2_complete:       bool  = false
var buttons_incapable:            bool  = false
var buttons_active:               bool  = false
var buttons_first_press_happened: bool  = false
var buttons_reach_time:           float = 0.0

var _complete:   bool         = false
var _last_step:  int          = 1
var _card_style: StyleBoxFlat = null
var _pulse_tw:   Tween        = null
var _warn_tw:    Tween        = null


# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	back_button      = get_node_or_null("back_button")
	save_button      = get_node_or_null("save_button")
	circleIndication = get_node_or_null("buttonstateUI")
	_hint_lbl        = get_node_or_null("hint_label")
	_arc_layer       = get_node_or_null("arc_layer")

	var card := get_node_or_null("card_buttons")
	_card_bg            = card
	_card_name_lbl      = card.get_node_or_null("phase_name")   if card else null
	_card_check         = card.get_node_or_null("check_lbl")    if card else null
	_card_step_lbl      = card.get_node_or_null("step_lbl")     if card else null
	_card_timer_lbl     = card.get_node_or_null("timer_lbl")    if card else null
	var pbg             := card.get_node_or_null("progress_bg") if card else null
	_card_prog_fill     = pbg.get_node_or_null("progress_fill") if pbg else null
	_card_step_a        = card.get_node_or_null("step_seg_a")   if card else null
	_card_step_b        = card.get_node_or_null("step_seg_b")   if card else null
	_card_incapable_btn = card.get_node_or_null("incapable_btn") if card else null
	_card_continue_btn  = card.get_node_or_null("continue_btn")  if card else null

	if _card_incapable_btn:
		_card_incapable_btn.pressed.connect(_on_incapable_pressed)
	if _card_continue_btn:
		_card_continue_btn.pressed.connect(_on_continue_pressed)

	_card_style = card.get_theme_stylebox("panel") as StyleBoxFlat if card else null

	_warning_panel      = get_node_or_null("warning_panel")
	_warning_msg_lbl    = get_node_or_null("warning_panel/warning_msg")
	_warning_ok_btn     = get_node_or_null("warning_panel/warning_ok_btn")
	_warning_cancel_btn = get_node_or_null("warning_panel/warning_cancel_btn")
	if _warning_ok_btn:
		_warning_ok_btn.pressed.connect(_on_warning_ok)
	if _warning_cancel_btn:
		_warning_cancel_btn.pressed.connect(_on_warning_cancel)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		save_button.visible = false

	AssessmentBase.hold_just_completed.connect(_on_hold_just_completed)
	AssessmentBase.step2_hold_registered.connect(_on_step2_hold_registered)
	AssessmentBase.reset_phase()

	if HCcomm:
		HCcomm.new_device_data.connect(_on_device_data_received)

	_refresh_ui()


# ─────────────────────────────────────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_update_card()
	_update_hint()
	_update_circle_color()
	if _arc_layer:
		_arc_layer.queue_redraw()


func _update_card() -> void:
	var base := AssessmentBase
	var col  := PHASE_COLOR

	if _card_style:
		if buttons_incapable:
			_card_style.bg_color     = Color(0.16, 0.04, 0.04, 1.0)
			_card_style.border_color = Color(0.55, 0.12, 0.12, 0.9)
			_card_style.shadow_color = Color(0.35, 0.04, 0.04, 0.5)
			_card_style.shadow_size  = 10
		elif _complete:
			_card_style.bg_color     = Color(col.r * 0.10, col.g * 0.10, col.b * 0.10, 1.0)
			_card_style.border_color = Color(col.r * 0.38, col.g * 0.38, col.b * 0.38, 0.6)
			_card_style.shadow_color = Color(col.r, col.g, col.b, 0.06)
			_card_style.shadow_size  = 4
		else:
			_card_style.bg_color     = Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 1.0)
			_card_style.border_color = Color(col.r, col.g, col.b, 0.92)
			_card_style.shadow_color = Color(col.r, col.g, col.b, 0.50)
			_card_style.shadow_size  = 20

	if _card_name_lbl:
		if buttons_incapable:
			_card_name_lbl.add_theme_color_override("font_color", Color(0.65, 0.22, 0.22, 1.0))
		elif _complete:
			_card_name_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.45))
		else:
			_card_name_lbl.add_theme_color_override("font_color", col)

	if _card_check:
		_card_check.visible = _complete

	if _card_step_lbl:
		if buttons_incapable:
			_card_step_lbl.text = "INCAPABLE"
			_card_step_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 0.85))
		elif _complete:
			_card_step_lbl.text = "DONE"
			_card_step_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
		else:
			_card_step_lbl.text = "STEP %d" % base.current_step
			_card_step_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))

	if _card_timer_lbl:
		_card_timer_lbl.text = ("%ds" % max(int(base.TIME_LIMIT - base.phase_timer), 0)) if (base.current_step == 2 and not _complete) else ""

	if _card_prog_fill:
		if _complete and not buttons_incapable:
			_card_prog_fill.offset_right = PROG_FILL_W
		elif buttons_incapable:
			_card_prog_fill.offset_right = 0.0

	var bar_col := Color(col.r, col.g, col.b, 0.85)
	var dim_col := Color(0.15, 0.15, 0.15, 1.0)
	if _card_step_a:
		_card_step_a.color = bar_col if (buttons_step1_complete and not buttons_incapable) else dim_col
	if _card_step_b:
		_card_step_b.color = bar_col if (_complete and not buttons_incapable) else dim_col

	if _card_continue_btn:
		if not _complete and base.current_step == 1 and buttons_step1_complete:
			_card_continue_btn.text = "Continue"
			_card_continue_btn.visible = true
		elif not _complete and base.current_step == 2:
			_card_continue_btn.text = "Redo"
			_card_continue_btn.visible = true
		else:
			_card_continue_btn.visible = false

	if _card_incapable_btn:
		_card_incapable_btn.visible = not _complete


func _update_active_progress() -> void:
	if _card_prog_fill == null or _complete:
		return
	var base := AssessmentBase
	if base.current_step == 1 and buttons_active:
		_card_prog_fill.offset_right = clampf(base.hold_timer / base.HOLD_TIME, 0.0, 1.0) * PROG_FILL_W
	elif base.current_step == 2:
		_card_prog_fill.offset_right = (float(base.hold_count) / base.HOLDS_REQUIRED) * PROG_FILL_W


func _update_hint() -> void:
	if _hint_lbl == null:
		return
	if _complete:
		_hint_lbl.text = "ALL DONE  —  TAP SAVE"
		_hint_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		return

	if _hold_complete():
		_hint_lbl.text = "RELEASE  ↑"
		_hint_lbl.add_theme_color_override("font_color", Color.WHITE)
		return

	var base := AssessmentBase
	_hint_lbl.add_theme_color_override("font_color", PHASE_COLOR)

	if base.current_step == 1:
		if not buttons_first_press_happened:
			_hint_lbl.text = "PRESS  →  HOLD  5 s"
		elif buttons_active:
			_hint_lbl.text = "KEEP HOLDING..."
		elif buttons_step1_complete:
			_hint_lbl.text = "STEP 1 DONE  —  PRESS  CONTINUE"
			_hint_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		else:
			_hint_lbl.text = "PRESS  →  HOLD  5 s"
	else:
		if buttons_active:
			_hint_lbl.text = "HOLD  ·  %d / %d" % [base.hold_count, base.HOLDS_REQUIRED]
		elif base.hold_count >= base.HOLDS_REQUIRED:
			_hint_lbl.text = "ALL HOLDS DONE!"
		elif base.hold_count > 0:
			_hint_lbl.text = "RELEASE  →  PRESS AGAIN  ·  %d / %d" % [base.hold_count, base.HOLDS_REQUIRED]
		else:
			_hint_lbl.text = "PRESS AND HOLD  ·  0 / %d" % base.HOLDS_REQUIRED


func _update_circle_color() -> void:
	if circleIndication == null:
		return
	if _complete:
		circleIndication.modulate = Color(0.4, 0.4, 0.4, 1.0)
		return
	if buttons_active:
		circleIndication.modulate = PHASE_COLOR
	else:
		circleIndication.modulate = Color(PHASE_COLOR.r * 0.35, PHASE_COLOR.g * 0.35, PHASE_COLOR.b * 0.35, 1.0)


func _hold_complete() -> bool:
	if not buttons_active:
		return false
	var base   := AssessmentBase
	var target := base.HOLD_TIME if base.current_step == 1 else base.HOLD_TIME_STEP2
	return base.hold_timer >= target


# ─────────────────────────────────────────────────────────────────────────────
# DRAW
# ─────────────────────────────────────────────────────────────────────────────

func _draw_arc_content(canvas: Node2D) -> void:
	var center: Vector2
	var r_circ: float
	if circleIndication:
		center = canvas.to_local(circleIndication.global_position)
		r_circ = 135.0 * circleIndication.get_global_transform().get_scale().x
	else:
		center = Vector2(976.0, 597.0)
		r_circ = 202.5
	center.x += AssessmentBase.arc_shake_offset
	var r_arc := r_circ + 22.0
	if _complete and not buttons_incapable:
		canvas.draw_arc(center, r_arc, 0.0, TAU, 80, Color(0.18, 0.18, 0.18, 0.7), 20.0, true)
		canvas.draw_arc(center, r_arc, -PI * 0.5, -PI * 0.5 + TAU, 80, Color(1.0, 0.2, 0.2), 20.0, true)
		return
	if _complete:
		return
	var bg_col := Color(0.1, 0.6, 0.2, 0.65) if AssessmentBase.arc_fill < 1.0 else Color(0.18, 0.18, 0.18, 0.7)
	canvas.draw_arc(center, r_arc, 0.0, TAU, 80, bg_col, 20.0, true)
	if AssessmentBase.arc_fill > 0.001:
		var a0      := -PI * 0.5
		var arc_col := Color(1.0, 0.2, 0.2) if AssessmentBase.arc_fill >= 1.0 else Color(0.2, 1.0, 0.35)
		canvas.draw_arc(center, r_arc, a0, a0 + TAU * AssessmentBase.arc_fill, 80, arc_col, 20.0, true)


# ─────────────────────────────────────────────────────────────────────────────
# ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────

func _pulse_circle(pressed: bool) -> void:
	if circleIndication == null:
		return
	if _pulse_tw and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pulse_tw.tween_property(circleIndication, "scale",
		Vector2(1, 1) if pressed else Vector2(0.75, 0.75), 0.28)


func _nudge_continue_btn() -> void:
	if _card_continue_btn == null or not _card_continue_btn.visible:
		return
	_card_continue_btn.pivot_offset = _card_continue_btn.size * 0.5
	var tw := create_tween()
	tw.tween_property(_card_continue_btn, "scale", Vector2(1.18, 1.18), 0.08) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card_continue_btn, "scale", Vector2(1.0, 1.0), 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pop_circle() -> void:
	if circleIndication == null:
		return
	if _pulse_tw and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = create_tween()
	_pulse_tw.tween_property(circleIndication, "scale", Vector2(1, 1), 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_pulse_tw.tween_property(circleIndication, "scale", Vector2(1, 1), 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# ASSESSMENTBASE SIGNAL HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

func _on_hold_just_completed(completed_step: int) -> void:
	_pop_circle()
	if completed_step == 1:
		buttons_step1_complete = true
	_update_card()
	_update_hint()


func _on_step2_hold_registered(count: int) -> void:
	if count >= AssessmentBase.HOLDS_REQUIRED:
		buttons_step2_complete = true
		buttons_reach_time     = AssessmentBase.phase_timer
		_complete = true
		AssessmentBase.reset_phase()
		_update_card()
		_update_hint()
		_update_circle_color()
		if save_button:
			save_button.visible = true
	else:
		_update_card()
		_update_hint()


# ─────────────────────────────────────────────────────────────────────────────
# PROCESS
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _complete:
		if _arc_layer:
			_arc_layer.queue_redraw()
		return

	var base := AssessmentBase
	_last_step = base.current_step
	var effective_active := buttons_active and not (base.current_step == 1 and buttons_step1_complete)
	base.tick(delta, effective_active)

	if base.current_step == 2 and base.phase_timer >= base.TIME_LIMIT:
		_complete = true
		AssessmentBase.reset_phase()
		_update_card()
		_update_hint()
		_update_circle_color()
		if save_button:
			save_button.visible = true
		if _arc_layer:
			_arc_layer.queue_redraw()
		return

	_update_active_progress()

	if base.current_step == 2 and _card_timer_lbl:
		_card_timer_lbl.text = "%ds" % max(int(base.TIME_LIMIT - base.phase_timer), 0)

	if _arc_layer:
		_arc_layer.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# DEVICE DATA
# ─────────────────────────────────────────────────────────────────────────────

func _on_device_data_received() -> void:
	if _complete:
		return
	var was := buttons_active
	buttons_active = (HCcomm.button_1 == 0 or HCcomm.button_2 == 0 or
					  HCcomm.button_3 == 0 or HCcomm.button_4 == 0 or HCcomm.button_5 == 0)
	if was == buttons_active:
		return
	if buttons_active and not buttons_first_press_happened:
		buttons_first_press_happened = true
	if buttons_active and AssessmentBase.current_step == 1 and buttons_step1_complete:
		_nudge_continue_btn()
	if not buttons_active:
		AssessmentBase.stop_shake()
		if AssessmentBase.current_step == 1 and buttons_step1_complete:
			_update_card()
	_update_circle_color()
	_pulse_circle(buttons_active)
	_update_hint()


# ─────────────────────────────────────────────────────────────────────────────
# CONTINUE / INCAPABLE
# ─────────────────────────────────────────────────────────────────────────────

func _on_continue_pressed() -> void:
	var base := AssessmentBase
	if base.current_step == 1 and buttons_step1_complete:
		base.enter_step2()
		_update_card()
		_update_hint()
	elif base.current_step == 2:
		buttons_step2_complete = false
		buttons_reach_time     = 0.0
		base.enter_step2()
		_update_card()
		_update_hint()


func _on_incapable_pressed() -> void:
	if _warning_msg_lbl:
		_warning_msg_lbl.text = "Mark  BUTTONS  as INCAPABLE?\n\nResult will be saved as 0."
	_show_warning()


func _on_warning_ok() -> void:
	_hide_warning()
	buttons_incapable      = true
	buttons_step1_complete = true
	buttons_step2_complete = true
	_complete = true
	AssessmentBase.reset_phase()
	_update_card()
	_update_hint()
	_update_circle_color()
	if save_button:
		save_button.visible = true


func _on_warning_cancel() -> void:
	_hide_warning()


func _show_warning() -> void:
	if _warning_panel == null:
		return
	if _warn_tw and _warn_tw.is_valid():
		_warn_tw.kill()
	_warning_panel.pivot_offset = Vector2(400.0, 180.0)
	_warning_panel.scale    = Vector2(0.88, 0.88)
	_warning_panel.modulate = Color(1, 1, 1, 0)
	_warning_panel.visible  = true
	_warn_tw = create_tween().set_parallel(true)
	_warn_tw.tween_property(_warning_panel, "scale",    Vector2(1.0, 1.0),   0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_warn_tw.tween_property(_warning_panel, "modulate", Color(1, 1, 1, 1), 0.18)


func _hide_warning() -> void:
	if _warning_panel == null:
		return
	if _warn_tw and _warn_tw.is_valid():
		_warn_tw.kill()
	_warn_tw = create_tween().set_parallel(true)
	_warn_tw.tween_property(_warning_panel, "scale",    Vector2(0.88, 0.88), 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_warn_tw.tween_property(_warning_panel, "modulate", Color(1, 1, 1, 0),   0.14)
	_warn_tw.chain().tween_callback(func():
		if _warning_panel:
			_warning_panel.visible  = false
			_warning_panel.scale    = Vector2(1.0, 1.0)
			_warning_panel.modulate = Color(1, 1, 1, 1)
	)


# ─────────────────────────────────────────────────────────────────────────────
# SAVE / NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────

func _on_save_pressed() -> void:
	var mech: HyperCubeMechanism = Appdata.selected_mechanism
	if mech == null:
		push_error("ButtonsAssessment: no mechanism selected")
		return

	if buttons_incapable:
		_cleanup()
		get_tree().change_scene_to_file("res://scene/mechanism.tscn")
		return

	var buttons_rom := mech.new_rom as ButtonsROM
	if buttons_rom == null:
		push_error("ButtonsAssessment: new_rom is not ButtonsROM")
		return
	buttons_rom.set_buttons_data(true, buttons_reach_time)
	if not buttons_rom.write_to_assessment_file():
		if _hint_lbl:
			_hint_lbl.text = "SAVE FAILED"
			_hint_lbl.add_theme_color_override("font_color", Color.RED)
		push_error("ButtonsAssessment: ROM write failed")
		return

	if _hint_lbl:
		_hint_lbl.text = "✓  SAVED"
		_hint_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
	_cleanup()
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")


func _on_back_pressed() -> void:
	_cleanup()
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")


func _cleanup() -> void:
	if HCcomm and HCcomm.is_connected("new_device_data", Callable(self, "_on_device_data_received")):
		HCcomm.disconnect("new_device_data", Callable(self, "_on_device_data_received"))
	if AssessmentBase.hold_just_completed.is_connected(_on_hold_just_completed):
		AssessmentBase.hold_just_completed.disconnect(_on_hold_just_completed)
	if AssessmentBase.step2_hold_registered.is_connected(_on_step2_hold_registered):
		AssessmentBase.step2_hold_registered.disconnect(_on_step2_hold_registered)
	AssessmentBase.stop_shake()


func _exit_tree() -> void:
	_cleanup()
