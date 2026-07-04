extends Node2D

# ── node refs ─────────────────────────────────────────────────────────────────
var back_button:      Button   = null
var save_button:      Button   = null
var circleIndication: Sprite2D = null
var _hint_lbl:        Label    = null
var _arc_layer:       Node2D   = null

# ── scene card nodes ──────────────────────────────────────────────────────────
const CARD_NODES_LIST := ["card_pinch1", "card_pinch2"]
var _card_bg:            Array = []
var _card_name_lbl:      Array = []
var _card_checks:        Array = []
var _card_step_lbl:      Array = []
var _card_timer_lbl:     Array = []
var _card_prog_fills:    Array = []
var _card_step_a:        Array = []
var _card_step_b:        Array = []
var _card_continue_btn:  Array = []
var _card_incapable_btn: Array = []

# ── warning panel ─────────────────────────────────────────────────────────────
var _warning_panel:      Control = null
var _warning_msg_lbl:    Label   = null
var _warning_ok_btn:     Button  = null
var _warning_cancel_btn: Button  = null
var _warning_phase:      int     = -1

# ── phase constants ───────────────────────────────────────────────────────────
const PROG_FILL_W := 470.0

const PHASE_COLORS := [
	Color(0.0,  0.9, 1.0),
	Color(0.78, 0.0, 1.0),
]

# ── assessment state ──────────────────────────────────────────────────────────
var pinch1_step1_complete: bool  = false
var pinch1_step2_complete: bool  = false
var pinch2_step1_complete: bool  = false
var pinch2_step2_complete: bool  = false
var pinch1_incapable:      bool  = false
var pinch2_incapable:      bool  = false

var pinch1_active: bool = false
var pinch2_active: bool = false

var pinch1_first_press_happened: bool = false
var pinch2_first_press_happened: bool = false

var pinch1_reach_time: float = 0.0
var pinch2_reach_time: float = 0.0

enum AssessmentPhase { PINCH1, PINCH2, COMPLETE }
var current_phase := AssessmentPhase.PINCH1

# ── draw / animation state ────────────────────────────────────────────────────
var _card_styles: Array = []
var _last_step:   int   = 1
var _pulse_tw:    Tween = null
var _warn_tw:     Tween = null


# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	back_button      = get_node_or_null("back_button")
	save_button      = get_node_or_null("save_button")
	circleIndication = get_node_or_null("buttonstateUI")
	_hint_lbl        = get_node_or_null("hint_label")
	_arc_layer       = get_node_or_null("arc_layer")

	_warning_panel      = get_node_or_null("warning_panel")
	_warning_msg_lbl    = get_node_or_null("warning_panel/warning_msg")
	_warning_ok_btn     = get_node_or_null("warning_panel/warning_ok_btn")
	_warning_cancel_btn = get_node_or_null("warning_panel/warning_cancel_btn")
	if _warning_ok_btn:
		_warning_ok_btn.pressed.connect(_on_warning_ok)
	if _warning_cancel_btn:
		_warning_cancel_btn.pressed.connect(_on_warning_cancel)

	for i in CARD_NODES_LIST.size():
		var ci   := i
		var card := get_node_or_null(CARD_NODES_LIST[i])
		_card_bg.append(card)
		_card_name_lbl.append(card.get_node_or_null("phase_name") if card else null)
		_card_checks.append(card.get_node_or_null("check_lbl") if card else null)
		_card_step_lbl.append(card.get_node_or_null("step_lbl") if card else null)
		_card_timer_lbl.append(card.get_node_or_null("timer_lbl") if card else null)
		var pbg := card.get_node_or_null("progress_bg") if card else null
		_card_prog_fills.append(pbg.get_node_or_null("progress_fill") if pbg else null)
		_card_step_a.append(card.get_node_or_null("step_seg_a") if card else null)
		_card_step_b.append(card.get_node_or_null("step_seg_b") if card else null)

		var incap_btn := card.get_node_or_null("incapable_btn") if card else null
		_card_incapable_btn.append(incap_btn)
		if incap_btn:
			incap_btn.pressed.connect(func(): _on_incapable_pressed(ci))

		var cont_btn := card.get_node_or_null("continue_btn") if card else null
		_card_continue_btn.append(cont_btn)
		if cont_btn:
			cont_btn.pressed.connect(func(): _on_continue_pressed(ci))

		if card:
			card.gui_input.connect(func(ev): _on_card_gui_input(ev, ci))

		_card_styles.append(card.get_theme_stylebox("panel") as StyleBoxFlat if card else null)

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
# CARD SELECTION
# ─────────────────────────────────────────────────────────────────────────────

func _on_card_gui_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and
			(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _is_phase_done(idx) or idx == _phase_index():
		return
	_select_phase(idx)


func _select_phase(idx: int) -> void:
	var phases := [AssessmentPhase.PINCH1, AssessmentPhase.PINCH2]
	current_phase = phases[idx]
	AssessmentBase.reset_phase()
	_reset_phase_assessment(idx)
	_refresh_ui()


func _reset_phase_assessment(idx: int) -> void:
	match idx:
		0:
			pinch1_step1_complete = false; pinch1_step2_complete = false
			pinch1_first_press_happened = false
			pinch1_reach_time = 0.0;       pinch1_incapable     = false
		1:
			pinch2_step1_complete = false; pinch2_step2_complete = false
			pinch2_first_press_happened = false
			pinch2_reach_time = 0.0;       pinch2_incapable     = false


func _is_phase_done(i: int) -> bool:
	match i:
		0: return pinch1_incapable or (pinch1_step1_complete and pinch1_step2_complete)
		1: return pinch2_incapable or (pinch2_step1_complete and pinch2_step2_complete)
	return false


func _find_next_unfinished() -> AssessmentPhase:
	for i in 2:
		if not _is_phase_done(i):
			return ([AssessmentPhase.PINCH1, AssessmentPhase.PINCH2] as Array)[i]
	return AssessmentPhase.COMPLETE


# ─────────────────────────────────────────────────────────────────────────────
# CONTINUE / INCAPABLE
# ─────────────────────────────────────────────────────────────────────────────

func _on_continue_pressed(idx: int) -> void:
	if idx != _phase_index():
		return
	if AssessmentBase.current_step == 1 and _step1_done():
		AssessmentBase.enter_step2()
		_update_cards()
		_update_hint()
	elif AssessmentBase.current_step == 2:
		_reset_step2_for_phase()
		AssessmentBase.enter_step2()
		_update_cards()
		_update_hint()


func _reset_step2_for_phase() -> void:
	match current_phase:
		AssessmentPhase.PINCH1: pinch1_step2_complete = false; pinch1_reach_time = 0.0
		AssessmentPhase.PINCH2: pinch2_step2_complete = false; pinch2_reach_time = 0.0


func _on_incapable_pressed(idx: int) -> void:
	_warning_phase = idx
	var names := ["PINCH 1", "PINCH 2"]
	if _warning_msg_lbl:
		_warning_msg_lbl.text = "Mark  %s  as INCAPABLE?\n\nResult will be saved as 0." % names[idx]
	_show_warning()


func _on_warning_ok() -> void:
	_hide_warning()
	if _warning_phase < 0:
		return
	match _warning_phase:
		0: pinch1_incapable = true; pinch1_step1_complete = true; pinch1_step2_complete = true
		1: pinch2_incapable = true; pinch2_step1_complete = true; pinch2_step2_complete = true
	_warning_phase = -1
	_advance_phase(_find_next_unfinished())


func _on_warning_cancel() -> void:
	_hide_warning()
	_warning_phase = -1


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
# UI UPDATE
# ─────────────────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_update_cards()
	_update_hint()
	_update_circle_color()
	if _arc_layer:
		_arc_layer.queue_redraw()


func _phase_index() -> int:
	match current_phase:
		AssessmentPhase.PINCH1: return 0
		AssessmentPhase.PINCH2: return 1
	return -1


func _get_phase_color() -> Color:
	var idx := _phase_index()
	return PHASE_COLORS[idx] if idx >= 0 else Color.WHITE


func _update_cards() -> void:
	var step1 := [pinch1_step1_complete, pinch2_step1_complete]
	var incap  := [pinch1_incapable, pinch2_incapable]
	var idx    := _phase_index()
	var base   := AssessmentBase

	for i in 2:
		var is_active:    bool  = (i == idx)
		var is_done:      bool  = _is_phase_done(i)
		var is_incapable: bool  = incap[i]
		var col:          Color = PHASE_COLORS[i]

		if _card_bg[i] and _card_styles.size() > i:
			var sbox: StyleBoxFlat = _card_styles[i]
			if is_incapable:
				sbox.bg_color     = Color(0.16, 0.04, 0.04, 1.0)
				sbox.border_color = Color(0.55, 0.12, 0.12, 0.9)
				sbox.shadow_color = Color(0.35, 0.04, 0.04, 0.5)
				sbox.shadow_size  = 10
			elif is_done:
				sbox.bg_color     = Color(col.r * 0.10, col.g * 0.10, col.b * 0.10, 1.0)
				sbox.border_color = Color(col.r * 0.38, col.g * 0.38, col.b * 0.38, 0.6)
				sbox.shadow_color = Color(col.r, col.g, col.b, 0.06)
				sbox.shadow_size  = 4
			elif is_active:
				sbox.bg_color     = Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 1.0)
				sbox.border_color = Color(col.r, col.g, col.b, 0.92)
				sbox.shadow_color = Color(col.r, col.g, col.b, 0.50)
				sbox.shadow_size  = 20
			else:
				sbox.bg_color     = Color(0.08, 0.08, 0.08, 1.0)
				sbox.border_color = Color(0.18, 0.18, 0.18, 0.5)
				sbox.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
				sbox.shadow_size  = 0

		if _card_name_lbl[i]:
			if is_incapable:
				_card_name_lbl[i].add_theme_color_override("font_color", Color(0.65, 0.22, 0.22, 1.0))
			elif is_done:
				_card_name_lbl[i].add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.45))
			elif is_active:
				_card_name_lbl[i].add_theme_color_override("font_color", col)
			else:
				_card_name_lbl[i].add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1.0))

		if _card_checks[i]:
			_card_checks[i].visible = is_done

		if _card_step_lbl[i]:
			if is_incapable:
				_card_step_lbl[i].text = "INCAPABLE"
				_card_step_lbl[i].add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 0.85))
			elif is_active:
				_card_step_lbl[i].text = "STEP %d" % base.current_step
				_card_step_lbl[i].add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
			else:
				_card_step_lbl[i].text = "STEP 1"
				_card_step_lbl[i].add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1.0))

		if _card_timer_lbl[i]:
			_card_timer_lbl[i].text = ("%ds" % max(int(base.TIME_LIMIT - base.phase_timer), 0)) if (is_active and base.current_step == 2) else ""

		if _card_prog_fills[i]:
			if is_done and not is_incapable:
				_card_prog_fills[i].offset_right = PROG_FILL_W
			elif not is_active or is_incapable:
				_card_prog_fills[i].offset_right = 0.0

		var bar_col := Color(col.r, col.g, col.b, 0.85)
		var dim_col := Color(0.15, 0.15, 0.15, 1.0)
		if _card_step_a[i]:
			_card_step_a[i].color = bar_col if (step1[i] and not is_incapable) else dim_col
		if _card_step_b[i]:
			_card_step_b[i].color = bar_col if (is_done and not is_incapable) else dim_col

		if _card_continue_btn[i]:
			if is_active and base.current_step == 1 and _step1_done():
				_card_continue_btn[i].text = "Continue"
				_card_continue_btn[i].visible = true
			elif is_active and base.current_step == 2:
				_card_continue_btn[i].text = "Redo"
				_card_continue_btn[i].visible = true
			else:
				_card_continue_btn[i].visible = false

		if _card_incapable_btn[i]:
			_card_incapable_btn[i].visible = not is_done


func _update_active_progress() -> void:
	var idx  := _phase_index()
	if idx < 0 or _card_prog_fills[idx] == null:
		return
	var base := AssessmentBase
	if base.current_step == 1 and _is_current_active():
		_card_prog_fills[idx].offset_right = clampf(base.hold_timer / base.HOLD_TIME, 0.0, 1.0) * PROG_FILL_W
	elif base.current_step == 2:
		_card_prog_fills[idx].offset_right = (float(base.hold_count) / base.HOLDS_REQUIRED) * PROG_FILL_W


func _update_hint() -> void:
	if _hint_lbl == null:
		return
	if current_phase == AssessmentPhase.COMPLETE:
		_hint_lbl.text = "ALL DONE  —  TAP SAVE"
		_hint_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		return

	if _hold_complete():
		_hint_lbl.text = "RELEASE  ↑"
		_hint_lbl.add_theme_color_override("font_color", Color.WHITE)
		return

	var base := AssessmentBase
	var col  := _get_phase_color()
	_hint_lbl.add_theme_color_override("font_color", col)

	if base.current_step == 1:
		if not _first_press_happened():
			_hint_lbl.text = "PULL  →  HOLD  5 s"
		elif _is_current_active():
			_hint_lbl.text = "KEEP HOLDING..."
		elif _step1_done():
			_hint_lbl.text = "STEP 1 DONE  —  PRESS  CONTINUE"
			_hint_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		else:
			_hint_lbl.text = "PULL  →  HOLD  5 s"
	else:
		if _is_current_active():
			_hint_lbl.text = "HOLD  ·  %d / %d" % [base.hold_count, base.HOLDS_REQUIRED]
		elif base.hold_count >= base.HOLDS_REQUIRED:
			_hint_lbl.text = "ALL HOLDS DONE!"
		elif base.hold_count > 0:
			_hint_lbl.text = "RELEASE  →  PULL AGAIN  ·  %d / %d" % [base.hold_count, base.HOLDS_REQUIRED]
		else:
			_hint_lbl.text = "PULL AND HOLD  ·  0 / %d" % base.HOLDS_REQUIRED


func _update_circle_color() -> void:
	if circleIndication == null:
		return
	if current_phase == AssessmentPhase.COMPLETE:
		circleIndication.modulate = Color(0.4, 0.4, 0.4, 1.0)
		return
	var col := _get_phase_color()
	if _is_current_active():
		circleIndication.modulate = col
	else:
		circleIndication.modulate = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 1.0)


func _is_current_active() -> bool:
	match current_phase:
		AssessmentPhase.PINCH1: return pinch1_active
		AssessmentPhase.PINCH2: return pinch2_active
	return false


func _first_press_happened() -> bool:
	match current_phase:
		AssessmentPhase.PINCH1: return pinch1_first_press_happened
		AssessmentPhase.PINCH2: return pinch2_first_press_happened
	return false


func _step1_done() -> bool:
	match current_phase:
		AssessmentPhase.PINCH1: return pinch1_step1_complete
		AssessmentPhase.PINCH2: return pinch2_step1_complete
	return false


func _hold_complete() -> bool:
	if not _is_current_active():
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
	if current_phase == AssessmentPhase.COMPLETE:
		var both_incapable := pinch1_incapable and pinch2_incapable
		if not both_incapable:
			canvas.draw_arc(center, r_arc, 0.0, TAU, 80, Color(0.18, 0.18, 0.18, 0.7), 20.0, true)
			canvas.draw_arc(center, r_arc, -PI * 0.5, -PI * 0.5 + TAU, 80, Color(1.0, 0.2, 0.2), 20.0, true)
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


func _nudge_continue_btn(idx: int) -> void:
	var btn: Button = _card_continue_btn[idx] if idx >= 0 and idx < _card_continue_btn.size() else null
	if btn == null or not btn.visible:
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.08) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.35) \
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
		match current_phase:
			AssessmentPhase.PINCH1: pinch1_step1_complete = true
			AssessmentPhase.PINCH2: pinch2_step1_complete = true
	_update_cards()
	_update_hint()


func _on_step2_hold_registered(count: int) -> void:
	if count >= AssessmentBase.HOLDS_REQUIRED:
		match current_phase:
			AssessmentPhase.PINCH1:
				pinch1_step2_complete = true
				pinch1_reach_time     = AssessmentBase.phase_timer
				_advance_phase(_find_next_unfinished())
			AssessmentPhase.PINCH2:
				pinch2_step2_complete = true
				pinch2_reach_time     = AssessmentBase.phase_timer
				_advance_phase(_find_next_unfinished())
	else:
		_update_cards()
		_update_hint()


# ─────────────────────────────────────────────────────────────────────────────
# PROCESS
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if current_phase == AssessmentPhase.COMPLETE:
		if _arc_layer:
			_arc_layer.queue_redraw()
		return

	var base := AssessmentBase
	_last_step = base.current_step
	var effective_active := _is_current_active() and not (base.current_step == 1 and _step1_done())
	base.tick(delta, effective_active)

	if base.current_step == 2 and base.phase_timer >= base.TIME_LIMIT:
		_advance_phase(_find_next_unfinished())
		if _arc_layer:
			_arc_layer.queue_redraw()
		return

	_update_active_progress()

	if base.current_step == 2:
		var idx := _phase_index()
		if idx >= 0 and _card_timer_lbl[idx] != null:
			_card_timer_lbl[idx].text = "%ds" % max(int(base.TIME_LIMIT - base.phase_timer), 0)

	if _arc_layer:
		_arc_layer.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# DEVICE DATA
# ─────────────────────────────────────────────────────────────────────────────

func _on_device_data_received() -> void:
	match current_phase:
		AssessmentPhase.PINCH1: _handle_pinch1_data()
		AssessmentPhase.PINCH2: _handle_pinch2_data()


func _handle_pinch1_data() -> void:
	var was := pinch1_active
	pinch1_active = HCcomm.button_7 == 0
	_on_active_changed(was, pinch1_active)


func _handle_pinch2_data() -> void:
	var was := pinch2_active
	pinch2_active = HCcomm.button_6 == 0
	_on_active_changed(was, pinch2_active)


func _on_active_changed(was: bool, now: bool) -> void:
	if was == now:
		return
	if now and not _first_press_happened():
		match current_phase:
			AssessmentPhase.PINCH1: pinch1_first_press_happened = true
			AssessmentPhase.PINCH2: pinch2_first_press_happened = true
	if now and AssessmentBase.current_step == 1 and _step1_done():
		_nudge_continue_btn(_phase_index())
	if not now:
		AssessmentBase.stop_shake()
		if AssessmentBase.current_step == 1 and _step1_done():
			_update_cards()
	_update_circle_color()
	_pulse_circle(now)
	_update_hint()


# ─────────────────────────────────────────────────────────────────────────────
# PHASE FLOW
# ─────────────────────────────────────────────────────────────────────────────

func _advance_phase(next: AssessmentPhase) -> void:
	current_phase = next
	AssessmentBase.reset_phase()
	_update_cards()
	_update_hint()
	_update_circle_color()
	if next == AssessmentPhase.COMPLETE and save_button:
		save_button.visible = true


# ─────────────────────────────────────────────────────────────────────────────
# SAVE / NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────

func _on_save_pressed() -> void:
	var mech: HyperCubeMechanism = Appdata.selected_mechanism
	if mech == null:
		push_error("PinchAssessment: no mechanism selected")
		return

	if not (pinch1_incapable and pinch2_incapable):
		var pinch_rom := mech.new_rom as PinchROM
		if pinch_rom == null:
			push_error("PinchAssessment: new_rom is not PinchROM")
			return
		var p1_done := pinch1_step1_complete and pinch1_step2_complete and not pinch1_incapable
		var p2_done := pinch2_step1_complete and pinch2_step2_complete and not pinch2_incapable
		pinch_rom.set_pinch_data(p1_done, p2_done, pinch1_reach_time, pinch2_reach_time)
		if not pinch_rom.write_to_assessment_file():
			if _hint_lbl:
				_hint_lbl.text = "SAVE FAILED"
				_hint_lbl.add_theme_color_override("font_color", Color.RED)
			push_error("PinchAssessment: ROM write failed")
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
