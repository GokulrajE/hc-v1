extends Node2D

# CW  bar is 274 × 274  → center (137, 137)
# CCW bar is 274 × 256  → center (137, 128)
const CENTER_CW  := Vector2(137.0, 137.0)
const CENTER_CCW := Vector2(137.0, 128.0)
const ARC_R_CW   := 130.0
const ARC_R_CCW  := 120.0

const COL_MAX := Color(0.2, 0.95, 0.4, 1.0)
const COL_MIN := Color(0.3,  0.7, 1.0, 1.0)
const DIM     := 0.22

var arom_min    : float = 0.0
var arom_max    : float = 0.0
var going_to_max: bool  = false
var reach_count : int   = 0
var is_active   : bool  = false


func activate(amin: float, amax: float) -> void:
	arom_min     = amin
	arom_max     = amax
	going_to_max = false
	reach_count  = 0
	is_active    = true
	queue_redraw()


func update_state(to_max: bool, count: int) -> void:
	if going_to_max == to_max and reach_count == count:
		return
	going_to_max = to_max
	reach_count  = count
	queue_redraw()


func deactivate() -> void:
	is_active = false
	queue_redraw()


func _draw() -> void:
	if not is_active:
		return

	var max_dir := _dir(-90.0 + arom_max)
	var min_dir := _dir(-90.0 - absf(arom_min))

	_draw_target(max_dir, "MAX", COL_MAX, going_to_max,     CENTER_CW,  ARC_R_CW)
	_draw_target(min_dir, "MIN", COL_MIN, not going_to_max, CENTER_CCW, ARC_R_CCW)

	# Count — drawn last so it sits on top, above all other elements
	var a_center := CENTER_CW  if going_to_max else CENTER_CCW
	var a_arc_r  := ARC_R_CW  if going_to_max else ARC_R_CCW
	var a_dir    := max_dir    if going_to_max else min_dir
	var a_col    := COL_MAX    if going_to_max else COL_MIN
	_draw_count(a_center, a_dir, a_arc_r, a_col)


func _draw_target(
		dir   : Vector2,
		label : String,
		color : Color,
		active: bool,
		center: Vector2,
		arc_r : float) -> void:

	var c    := color if active else Color(color.r, color.g, color.b, DIM)
	var perp := Vector2(-dir.y, dir.x)
	var font := ThemeDB.fallback_font

	# 1. Perpendicular tick at the exact arc edge
	var arc_pt := center + dir * arc_r
	draw_line(arc_pt - perp * 16.0, arc_pt + perp * 16.0, c, 4.0)

	# 2. Arrow: fully outside the arc — tip starts 10 u past arc edge
	var tip    := arc_pt + dir * 10.0
	var base_l := arc_pt + dir * 28.0 + perp * 10.0
	var base_r := arc_pt + dir * 28.0 - perp * 10.0
	draw_polygon(PackedVector2Array([tip, base_l, base_r]), PackedColorArray([c, c, c]))

	# 3. "MAX" / "MIN" label — centred above the arrow
	#    Shift left by half estimated text width so it sits on the radial line
	var lp := center + dir * (arc_r + 38.0) - Vector2(16.0, 0.0)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)


func _draw_count(center: Vector2, dir: Vector2, arc_r: float, color: Color) -> void:
	# Digit sits furthest out, clearly separated from the label
	var font := ThemeDB.fallback_font
	var cp   := center + dir * (arc_r + 60.0) - Vector2(12.0, 0.0)
	draw_string(font, cp, str(reach_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)


func _dir(deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(cos(r), sin(r))
