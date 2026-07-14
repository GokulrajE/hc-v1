extends Control

var time_left: float = 7.0
var time_max:  float = 7.0

var _label: Label = null
var _punch_tw: Tween = null
var _last_ceil: int = -1


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 50)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.text = "7"
	add_child(_label)


func set_time(tl: float, tm: float) -> void:
	time_left = tl
	time_max  = tm

	var ct := ceili(tl)
	if ct != _last_ceil:
		_last_ceil = ct
		_punch()

	var col: Color
	if tl <= 1.0:
		col = Color(1.0, 0.18, 0.18)
	elif tl <= 3.0:
		col = Color(1.0, 0.78, 0.08)
	else:
		col = Color(1.0, 1.0, 1.0)

	if _label:
		_label.text = "%d" % maxi(ct, 0)
		_label.add_theme_color_override("font_color", col)

	queue_redraw()


func _punch() -> void:
	if _punch_tw and _punch_tw.is_valid():
		_punch_tw.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	_punch_tw = create_tween()
	_punch_tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.07) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.20) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var cx  := size.x * 0.5
	var cy  := size.y * 0.5
	var r   := minf(cx, cy) - 6.0
	var lw  := 11.0

	# Dark background ring
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 72, Color(0.0, 0.0, 0.0, 0.45), lw, true)

	# Colored fill arc — clockwise from top, depletes as time runs out
	var frac := clampf(time_left / time_max, 0.0, 1.0)
	if frac > 0.0:
		var col: Color
		if frac > 0.5:
			col = Color(0.15, 0.95, 0.25)   # green
		elif frac > 0.28:
			col = Color(1.0, 0.78, 0.08)    # yellow
		else:
			col = Color(1.0, 0.18, 0.18)    # red
		var start_a := -PI * 0.5
		draw_arc(Vector2(cx, cy), r, start_a, start_a + TAU * frac, 72, col, lw, true)
