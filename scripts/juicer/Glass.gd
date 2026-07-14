extends Node2D

var fruit_index = 0
var juice_level = 0.0
var is_full = false
var is_pouring = false
var completion_pulse = 1.0
var count: int = 0

var _count_label: Label = null

func _ready() -> void:
	_count_label = Label.new()
	_count_label.text = "🍹 0"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.position = Vector2(-60.0, 88.0)
	_count_label.custom_minimum_size = Vector2(120.0, 40.0)
	_count_label.add_theme_font_size_override("font_size", 42)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 4)
	# Use a dim version of the juice color so it's visible but not distracting at 0
	var base_col: Color = juice_colors[fruit_index]
	_count_label.add_theme_color_override("font_color", Color(base_col.r, base_col.g, base_col.b, 0.65))
	add_child(_count_label)


var juice_colors = [
	Color(1.0, 0.6, 0.1, 0.85),
	Color(0.95, 0.95, 0.1, 0.85),
	Color(0.95, 0.2, 0.2, 0.85),
	Color(0.55, 0.1, 0.75, 0.85),
	Color(0.75, 0.05, 0.25, 0.85)
]

var ripple_scale = 1.0
var bubble_positions = []
var bubble_rise_times = []

func start_juice():
	is_pouring = true

func finish_juice():
	is_pouring = false
	is_full = true
	juice_level = 1.0

	var ripple_tween = create_tween()
	ripple_tween.set_trans(Tween.TRANS_ELASTIC)
	ripple_tween.set_ease(Tween.EASE_OUT)
	ripple_tween.tween_property(self, "ripple_scale", 1.25, 0.4)
	ripple_tween.tween_property(self, "ripple_scale", 1.0, 0.3)

	var pulse_tween = create_tween()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(self, "completion_pulse", 1.15, 0.2)
	pulse_tween.tween_property(self, "completion_pulse", 1.0, 0.2)

func reset():
	is_full = false
	is_pouring = false
	juice_level = 0.0
	ripple_scale = 1.0
	completion_pulse = 1.0
	bubble_positions.clear()
	bubble_rise_times.clear()
	queue_redraw()


func reset_count() -> void:
	count = 0
	if _count_label:
		_count_label.text = "🍹 0"
		_count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))


func increment_count() -> void:
	count += 1
	var juice_col: Color = juice_colors[fruit_index]
	if _count_label:
		_count_label.text = "🍹 %d" % count
		_count_label.add_theme_color_override("font_color", juice_col.lightened(0.3))
		# Scale pop on the count label
		_count_label.pivot_offset = _count_label.size * 0.5
		var tw := create_tween()
		tw.tween_property(_count_label, "scale", Vector2(1.5, 1.5), 0.08) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(_count_label, "scale", Vector2(1.0, 1.0), 0.22) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# "+1" floating pop label
	var pop := Label.new()
	pop.text = "+1"
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.position = Vector2(-30.0, 70.0)
	pop.custom_minimum_size = Vector2(60.0, 36.0)
	pop.add_theme_font_size_override("font_size", 30)
	pop.add_theme_color_override("font_color", juice_col.lightened(0.5))
	pop.add_theme_color_override("font_outline_color", Color.BLACK)
	pop.add_theme_constant_override("outline_size", 4)
	add_child(pop)
	var pop_tw := create_tween()
	pop_tw.tween_property(pop, "position:y", 20.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop_tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	pop_tw.tween_callback(func(): pop.queue_free())


func _process(delta):
	if is_pouring or juice_level > 0:
		queue_redraw()

	if is_pouring:
		if randf() < 0.45 * delta:
			var bubble_x = randf_range(-14, 14)
			var bubble_y = 25.0
			bubble_positions.append(Vector2(bubble_x, bubble_y))
			bubble_rise_times.append(0.0)

	for i in range(bubble_rise_times.size() - 1, -1, -1):
		bubble_rise_times[i] += delta
		if bubble_rise_times[i] > 1.1:
			bubble_positions.remove_at(i)
			bubble_rise_times.remove_at(i)

func get_juice_color():
	return juice_colors[fruit_index]

func is_full_glass():
	return is_full

func _draw():
	var glass_width = 100
	var glass_height = 160
	var glass_outline_color = Color(0.75, 0.75, 0.85, 1.0)

	var grey_amount = 1.0 - juice_level
	var glass_fill_color = Color(0.55, 0.55, 0.6, grey_amount * 0.3)

	var top_left = Vector2(-glass_width / 2.0, -glass_height / 2.0) * ripple_scale * completion_pulse
	var top_right = Vector2(glass_width / 2.0, -glass_height / 2.0) * ripple_scale * completion_pulse
	var bottom_left = Vector2(-glass_width / 2.5, glass_height / 2.0) * ripple_scale * completion_pulse
	var bottom_right = Vector2(glass_width / 2.5, glass_height / 2.0) * ripple_scale * completion_pulse

	var points = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	draw_colored_polygon(points, glass_fill_color)

	draw_line(top_left, top_right, glass_outline_color, 4.0)
	draw_line(top_right, bottom_right, glass_outline_color, 4.0)
	draw_line(bottom_right, bottom_left, glass_outline_color, 4.0)
	draw_line(bottom_left, top_left, glass_outline_color, 4.0)

	var gloss_points = PackedVector2Array([
		top_left,
		top_left + Vector2(10, 0),
		top_left + Vector2(0, 16)
	])
	draw_colored_polygon(gloss_points, Color(1.0, 1.0, 1.0, 0.5))

	if juice_level > 0:
		var juice_height = (glass_height - 4) * juice_level
		var juice_y_start = glass_height / 2.0 - juice_height
		var juice_y_end = glass_height / 2.0

		var juice_top_left = Vector2(
			-glass_width / 2.0 + 2,
			juice_y_start
		) * ripple_scale * completion_pulse
		var juice_top_right = Vector2(
			glass_width / 2.0 - 2,
			juice_y_start
		) * ripple_scale * completion_pulse
		var juice_bottom_left = Vector2(
			-glass_width / 2.5 + 1,
			juice_y_end - 2
		) * ripple_scale * completion_pulse
		var juice_bottom_right = Vector2(
			glass_width / 2.5 - 1,
			juice_y_end - 2
		) * ripple_scale * completion_pulse

		var juice_points = PackedVector2Array([
			juice_top_left,
			juice_top_right,
			juice_bottom_right,
			juice_bottom_left
		])

		var juice_color = juice_colors[fruit_index]
		draw_colored_polygon(juice_points, juice_color)

		draw_line(juice_top_left, juice_top_right, juice_color.lightened(0.5), 3.0)
		draw_line(juice_top_left, juice_top_right, juice_color.lightened(0.7), 1.5)

		for i in range(bubble_positions.size()):
			var bubble_pos = bubble_positions[i]
			var rise_progress = bubble_rise_times[i]

			var bubble_y = juice_y_end - 15 - (rise_progress * 45)
			var bubble_x = bubble_pos.x
			var bubble_size = 2.5 - (rise_progress * 1.8)

			if bubble_y > juice_y_start and bubble_size > 0.2:
				var bubble_world_pos = Vector2(bubble_x, bubble_y) * ripple_scale * completion_pulse
				draw_circle(bubble_world_pos, bubble_size, juice_color.lightened(0.6))
				draw_circle(bubble_world_pos, bubble_size * 0.6, juice_color.lightened(0.8))
