extends Control
class_name AngleGauge

# Configuration
var min_angle: float = 0.0
var max_angle: float = 120.0
var current_angle: float = 0.0

# Visual properties
var gauge_radius: float = 200.0
var gauge_width: float = 20.0
var gauge_center: Vector2

# Zone colors for different states
var zone_colors: Dictionary = {
	"background": Color(0.0, 0.0, 0.0, 1.0),
	"default": Color(0.724, 0.496, 0.979, 1.0),
	"validation_yellow": Color(1.0, 0.85, 0.0, 1.0),
	"validation_green": Color(0.0, 0.8, 0.4, 1.0),
}

# Shade zones - list of {start_angle, end_angle, color}
var shade_zones: Array = []

# Needle properties
var needle_color: Color = Color.WHITE
var needle_width: float = 4.0

# Labels
var show_labels: bool = true
var label_font_size: int = 16

# Step 3 reaching animation
var step3_active:  bool  = false
var s3_arom_min:   float = 0.0
var s3_arom_max:   float = 0.0
var going_to_max:  bool  = false
var pulse_time:    float = 0.0

const COL_S3_MAX := Color(0.2,  0.95, 0.4,  1.0)
const COL_S3_MIN := Color(0.3,  0.7,  1.0,  1.0)
const DIM        := 0.08

func _ready() -> void:
	gauge_center = size / 2.0
	resized.connect(_on_resized)


func _process(delta: float) -> void:
	if step3_active:
		pulse_time += delta * 3.0
		queue_redraw()

func _on_resized() -> void:
	gauge_center = size / 2.0
	queue_redraw()

func set_current_angle(angle: float) -> void:
	current_angle = clamp(angle, min_angle, max_angle)
	queue_redraw()

func add_shade_zone(start_angle: float, end_angle: float, color: Color) -> void:
	shade_zones.append({
		"start": start_angle,
		"end": end_angle,
		"color": color
	})
	queue_redraw()

func clear_shade_zones() -> void:
	shade_zones.clear()
	queue_redraw()

func set_gauge_color(state: String) -> void:
	if state in zone_colors:
		queue_redraw()


func activate_step3(amin: float, amax: float, to_max: bool) -> void:
	step3_active = true
	s3_arom_min  = amin
	s3_arom_max  = amax
	going_to_max = to_max
	pulse_time   = 0.0
	queue_redraw()


func update_step3(to_max: bool) -> void:
	if going_to_max == to_max:
		return
	going_to_max = to_max
	queue_redraw()


func clear_step3() -> void:
	step3_active = false
	queue_redraw()

func _draw() -> void:
	gauge_center = size / 2.0

	# Draw background circle
	draw_circle(gauge_center, gauge_radius, zone_colors["background"])

	# Draw gauge track (the full 0-120° range)
	_draw_arc_track()

	# Draw shade zones (validation limits, AROM ranges)
	_draw_shade_zones()

	# Step 3: pulsing path arc from needle toward the active target
	if step3_active:
		var pulse        := sin(pulse_time) * 0.5 + 0.5
		var path_col_raw := COL_S3_MAX if going_to_max else COL_S3_MIN
		var path_alpha   := 0.18 + pulse * 0.28
		var path_color   := Color(path_col_raw.r, path_col_raw.g, path_col_raw.b, path_alpha)
		var outer_r      := gauge_radius + gauge_width * 0.5 + 14.0
		if going_to_max and current_angle < s3_arom_max:
			draw_arc(gauge_center, outer_r,
					 _s3_rad(current_angle), _s3_rad(s3_arom_max),
					 32, path_color, 10.0)
			_draw_s3_arrowhead(s3_arom_max, outer_r, path_col_raw, path_alpha, true)
		elif not going_to_max and current_angle > s3_arom_min:
			draw_arc(gauge_center, outer_r,
					 _s3_rad(s3_arom_min), _s3_rad(current_angle),
					 32, path_color, 10.0)
			_draw_s3_arrowhead(s3_arom_min, outer_r, path_col_raw, path_alpha, false)
		_draw_step3_marker(s3_arom_max, COL_S3_MAX, going_to_max,     "MAX")
		_draw_step3_marker(s3_arom_min, COL_S3_MIN, not going_to_max, "MIN")

	# Draw current angle indicator
	_draw_needle()

	# Draw degree markers and labels
	if show_labels:
		_draw_labels()

func _draw_arc_track() -> void:
	var start_rad = deg_to_rad(min_angle - 180.0)
	var end_rad = deg_to_rad(max_angle - 180.0)

	# Draw the track as an arc outline
	draw_arc(gauge_center, gauge_radius, start_rad, end_rad, 64, zone_colors["default"], gauge_width)

func _draw_shade_zones() -> void:
	for zone in shade_zones:
		var start_rad = deg_to_rad(zone["start"] - 180.0)
		var end_rad = deg_to_rad(zone["end"] - 180.0)

		# Draw filled arc for the zone
		_draw_filled_arc(
			gauge_center,
			gauge_radius - gauge_width / 2.0,
			start_rad,
			end_rad,
			zone["color"],
			32
		)

func _draw_filled_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, segments: int) -> void:
	var points: PackedVector2Array = [center]
	var angle_step = (end_angle - start_angle) / segments

	for i in range(segments + 1):
		var angle = start_angle + (angle_step * i)
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)

	points.append(center)
	draw_colored_polygon(points, color)

func _draw_needle() -> void:
	var current_rad = deg_to_rad(current_angle - 180.0)

	# Draw line from center to outer edge
	var outer_point = gauge_center + Vector2(cos(current_rad), sin(current_rad)) * (gauge_radius + 10)
	var inner_point = gauge_center + Vector2(cos(current_rad), sin(current_rad)) * (gauge_radius - gauge_width - 10)

	draw_line(inner_point, outer_point, needle_color, needle_width)

	# Draw circle at center
	draw_circle(gauge_center, 8, needle_color)

func _draw_labels() -> void:
	var font = get_theme_font("font")
	var font_size = label_font_size

	var current_deg = int(min_angle)
	while current_deg <= int(max_angle):
		var angle_rad = deg_to_rad(float(current_deg) - 180.0)

		# Draw small tick mark
		var tick_start = gauge_center + Vector2(cos(angle_rad), sin(angle_rad)) * (gauge_radius - 5)
		var tick_end = gauge_center + Vector2(cos(angle_rad), sin(angle_rad)) * (gauge_radius + 5)
		draw_line(tick_start, tick_end, Color.WHITE, 2)

		# Draw degree label
		var label_pos = gauge_center + Vector2(cos(angle_rad), sin(angle_rad)) * (gauge_radius + 25)
		draw_string(font, label_pos, str(current_deg) + "°", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

		current_deg += 20


func _s3_rad(deg: float) -> float:
	return deg_to_rad(deg - 180.0)


func _s3_dir(deg: float) -> Vector2:
	var r := _s3_rad(deg)
	return Vector2(cos(r), sin(r))


func _draw_s3_arrowhead(deg: float, r: float, color: Color, alpha: float, clockwise: bool) -> void:
	var dir     := _s3_dir(deg)
	var perp    := Vector2(-dir.y, dir.x)          # clockwise tangent on the arc
	var tangent := perp if clockwise else -perp    # direction of travel at tip
	var arc_pt  := gauge_center + dir * r
	var c       := Color(color.r, color.g, color.b, alpha + 0.3)

	var tip    := arc_pt
	var base_l := arc_pt - tangent * 20.0 + dir * 10.0
	var base_r := arc_pt - tangent * 20.0 - dir * 10.0
	draw_polygon(PackedVector2Array([tip, base_l, base_r]), PackedColorArray([c, c, c]))


func _draw_step3_marker(deg: float, color: Color, active: bool, label: String) -> void:
	var pulse  := (sin(pulse_time) * 0.5 + 0.5) if active else 0.0
	var c      := color if active else Color(color.r, color.g, color.b, DIM)
	var rad    := _s3_rad(deg)
	var dir    := Vector2(cos(rad), sin(rad))
	var perp   := Vector2(-dir.y, dir.x)
	var font   := ThemeDB.fallback_font
	var arc_pt := gauge_center + dir * (gauge_radius + gauge_width * 0.5)

	# Pulsing glow rings (active only)
	if active:
		for i in range(3):
			var gr := 12.0 + i * 9.0 + pulse * 10.0
			var ga := (0.45 - i * 0.12) * (0.35 + pulse * 0.65)
			draw_circle(arc_pt, gr, Color(color.r, color.g, color.b, ga))

	# Perpendicular tick — wider and taller when active
	var tick_len := (20.0 + pulse * 7.0) if active else 11.0
	var tick_w   := (5.5  + pulse * 2.5) if active else 3.0
	draw_line(arc_pt - perp * tick_len, arc_pt + perp * tick_len, c, tick_w)

	# Arrow triangle — scaled with pulse when active
	var s      := (1.0 + pulse * 0.55) if active else 1.0
	var tip    := arc_pt + dir *  8.0 * s
	var base_l := arc_pt + dir * 28.0 * s + perp * 11.0 * s
	var base_r := arc_pt + dir * 28.0 * s - perp * 11.0 * s
	draw_polygon(PackedVector2Array([tip, base_l, base_r]), PackedColorArray([c, c, c]))

	# Label — larger and further out when active
	var lp  := gauge_center + dir * (gauge_radius + gauge_width + (46.0 if active else 34.0)) - Vector2(14, 0)
	var lsz := 16 if active else 11
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, c)
