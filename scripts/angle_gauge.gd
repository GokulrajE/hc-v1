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

func _ready() -> void:
	gauge_center = size / 2.0
	resized.connect(_on_resized)

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

func _draw() -> void:
	gauge_center = size / 2.0

	# Draw background circle
	draw_circle(gauge_center, gauge_radius, zone_colors["background"])

	# Draw gauge track (the full 0-120° range)
	_draw_arc_track()

	# Draw shade zones (validation limits, AROM ranges)
	_draw_shade_zones()

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
