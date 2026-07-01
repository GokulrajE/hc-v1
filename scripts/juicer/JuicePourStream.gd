extends Node2D

var from_pos = Vector2.ZERO
var to_pos = Vector2.ZERO
var stream_color = Color.WHITE
var stream_progress = 0.0
var is_visible_stream = false
var stream_width = 6.0
var stream_tween: Tween
var pulse_time = 0.0

func show_stream(from: Vector2, to: Vector2, color: Color):
	from_pos = from
	to_pos = to
	stream_color = color
	is_visible_stream = true
	stream_progress = 0.0
	stream_width = 5.0
	pulse_time = 0.0

	if stream_tween:
		stream_tween.kill()

	stream_tween = create_tween()
	stream_tween.set_parallel(true)
	stream_tween.tween_property(self, "stream_progress", 1.0, 0.25)
	stream_tween.tween_property(self, "stream_width", 9.0, 0.25)

	stream_tween = create_tween()
	stream_tween.set_trans(Tween.TRANS_SINE)
	stream_tween.set_ease(Tween.EASE_IN_OUT)
	stream_tween.set_loops()
	stream_tween.tween_property(self, "stream_width", 5.0, 0.35)
	stream_tween.tween_property(self, "stream_width", 9.0, 0.35)

func hide_stream():
	is_visible_stream = false
	if stream_tween:
		stream_tween.kill()
	queue_redraw()

func _draw():
	if not is_visible_stream or stream_progress <= 0:
		return

	var local_from = to_local(from_pos)
	var local_to = to_local(to_pos)
	var current_to = local_from.lerp(local_to, stream_progress)

	var shadow_offset = Vector2(2, 2)
	draw_line(local_from + shadow_offset, current_to + shadow_offset,
		Color(0, 0, 0, 0.2), stream_width + 2.0)

	draw_line(local_from, current_to, stream_color, stream_width)

	var highlight_color = stream_color.lightened(0.4)
	draw_line(local_from, current_to, highlight_color, stream_width * 0.4)

	draw_circle(current_to, stream_width / 2.0, stream_color)
	draw_circle(current_to, stream_width * 0.35, stream_color.lightened(0.3))

	for i in range(1, 4):
		var droplet_progress = stream_progress * (0.5 + float(i) * 0.15)
		if droplet_progress < 1.0:
			var droplet_pos = local_from.lerp(current_to, droplet_progress)
			var droplet_size = 3.0 - (float(i) * 0.5)
			draw_circle(droplet_pos, droplet_size, stream_color)
			draw_circle(droplet_pos, droplet_size * 0.5, stream_color.lightened(0.4))

func _process(delta):
	if is_visible_stream:
		pulse_time += delta
		queue_redraw()
