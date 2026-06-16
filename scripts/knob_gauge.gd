extends Control
class_name KnobGauge

# Gauge geometry — auto-sized to the control rect
var track_width: float = 22.0

# State
var current_angle : float = 0.0
var display_min   : float = -45.0
var display_max   : float =  45.0

# Shade zone (step 2: live AROM tracking)
var shade_from   : float = 0.0
var shade_to     : float = 0.0
var shade_color  : Color = Color(0.42, 0.14, 0.61, 1.0)
var shade_visible: bool  = false

# Step 3 markers
var step3_active : bool  = false
var arom_min     : float = 0.0
var arom_max     : float = 0.0
var going_to_max : bool  = false
var reach_count  : int   = 0

# Range label color — yellow in step 1, green when complete, grey after
var range_label_color: Color = Color(0.65, 0.65, 0.65, 1.0)

# Track arc — color and visibility controlled per step
var track_color: Color = Color(0.14, 0.14, 0.18, 1.0)
var show_track : bool  = true

const COL_BG    := Color(0.04, 0.04, 0.07, 1.0)
const COL_TRACK := Color(0.14, 0.14, 0.18, 1.0)
const COL_NEEDLE := Color(1.0,  1.0,  1.0,  1.0)
const COL_MAX    := Color(0.2,  0.95, 0.4,  1.0)
const COL_MIN    := Color(0.3,  0.7,  1.0,  1.0)
const DIM        := 0.22


func _ready() -> void:
	resized.connect(queue_redraw)


# ── Public API ────────────────────────────────────────────────────────────────

func set_current_angle(angle: float) -> void:
	current_angle = angle
	queue_redraw()


func set_display_range(dmin: float, dmax: float) -> void:
	display_min = dmin
	display_max = dmax
	queue_redraw()


func set_range_label_color(color: Color) -> void:
	range_label_color = color
	queue_redraw()


func set_track(enabled: bool, color: Color = COL_TRACK) -> void:
	show_track  = enabled
	track_color = color
	queue_redraw()


func set_shade_zone(from_deg: float, to_deg: float, color: Color) -> void:
	shade_from    = from_deg
	shade_to      = to_deg
	shade_color   = color
	shade_visible = true
	queue_redraw()


func clear_shade_zone() -> void:
	shade_visible = false
	queue_redraw()


func activate_step3(amin: float, amax: float, to_max: bool, count: int) -> void:
	arom_min     = amin
	arom_max     = amax
	going_to_max = to_max
	reach_count  = count
	step3_active = true
	queue_redraw()


func update_step3(to_max: bool, count: int) -> void:
	if going_to_max == to_max and reach_count == count:
		return
	going_to_max = to_max
	reach_count  = count
	queue_redraw()


func clear_step3() -> void:
	step3_active = false
	queue_redraw()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var center := size / 2.0
	var radius := _radius()
	
	# Dark background circle
	draw_circle(center, radius + track_width * 0.5 + 10, COL_BG)

	# Track arc — slightly wider than the display range for context
	if show_track:
		draw_arc(center, radius,
				 _rad(display_min), _rad(display_max),
				 64, track_color, track_width)

	# Shade zone (step 2 live AROM zone, or step 3 fixed zone)
	if shade_visible:
		draw_arc(center, radius,
				 _rad(shade_from), _rad(shade_to),
				 64, shade_color, track_width)

	# Step 3 markers drawn on top of shade zone
	if step3_active:
		_draw_marker(center, radius, arom_max, COL_MAX, going_to_max,     "MAX")
		_draw_marker(center, radius, arom_min, COL_MIN, not going_to_max, "MIN")
		_draw_count(center, radius)

	# Needle
	_draw_needle(center, radius)

	# Min / max degree labels at track edges
	_draw_range_labels(center, radius)


func _draw_needle(center: Vector2, radius: float) -> void:
	var rad   := _rad(current_angle)
	var dir   := Vector2(cos(rad), sin(rad))
	var outer := center + dir * (radius + track_width * 0.5 + 8)
	var inner := center + dir * radius * 0.28
	draw_line(inner, outer, COL_NEEDLE, 3.5)
	draw_circle(center, 7.0, COL_NEEDLE)


func _draw_range_labels(center: Vector2, radius: float) -> void:
	var font := ThemeDB.fallback_font
	for deg in [display_min, display_max]:
		var dir := _dir(deg)
		var pos := center + dir * (radius + track_width + 26)
		draw_string(font, pos - Vector2(20, 8), "%.0f°" % deg,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, range_label_color)


func _draw_marker(center: Vector2, radius: float, deg: float,
				  color: Color, active: bool, label: String) -> void:
	var c    := color if active else Color(color.r, color.g, color.b, DIM)
	var dir  := _dir(deg)
	var perp := Vector2(-dir.y, dir.x)
	var font := ThemeDB.fallback_font

	# Perpendicular tick at the outer arc edge
	var arc_pt := center + dir * (radius + track_width * 0.5)
	draw_line(arc_pt - perp * 15.0, arc_pt + perp * 15.0, c, 4.0)

	# Arrow triangle outside the tick, tip pointing inward toward arc
	var tip    := arc_pt + dir *  8.0
	var base_l := arc_pt + dir * 26.0 + perp * 10.0
	var base_r := arc_pt + dir * 26.0 - perp * 10.0
	draw_polygon(PackedVector2Array([tip, base_l, base_r]), PackedColorArray([c, c, c]))

	# Label above the arrow
	var lp := center + dir * (radius + track_width + 34) - Vector2(14, 0)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)


func _draw_count(center: Vector2, _r: float) -> void:
	var col  := COL_MAX if going_to_max else COL_MIN
	var font := ThemeDB.fallback_font
	# Draw count centered inside the gauge face — never overlaps external markers
	draw_string(font, center + Vector2(-12, -16), str(reach_count),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _radius() -> float:
	# Auto-fit radius to control size with a fixed margin
	return min(size.x, size.y) * 0.5 - 28.0


func _rad(deg: float) -> float:
	# 0° = top (12 o'clock), positive = clockwise
	return deg_to_rad(deg - 90.0)


func _dir(deg: float) -> Vector2:
	var r := _rad(deg)
	return Vector2(cos(r), sin(r))
