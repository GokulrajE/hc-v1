extends Node2D

var fruit_index = 0
var is_highlighted = false
var is_selected = false
var juice_extracted = 0.0
var highlight_tween: Tween
var glow_scale = 1.0

@onready var sprite = $Sprite2D
@onready var area = $Area2D

var fruit_names = ["orange", "lemon", "strawberry", "Grapes", "pomogrenate"]
var fruit_colors = [
	Color(1.0, 0.55, 0.0),
	Color(1.0, 0.95, 0.2),
	Color(0.9, 0.15, 0.15),
	Color(0.5, 0.1, 0.7),
	Color(0.7, 0.05, 0.2)
]

var base_sprite_scale = Vector2(1.0, 1.0)

func _ready():
	var sprite_path = "res://assets/juicer/%s.png" % fruit_names[fruit_index]
	sprite.texture = load(sprite_path)
	sprite.modulate = Color.WHITE

	if sprite.texture:
		var texture_size = sprite.texture.get_size()
		var target_size = 160.0
		base_sprite_scale = Vector2(target_size / texture_size.x, target_size / texture_size.y)
		sprite.scale = base_sprite_scale

func highlight():
	is_highlighted = true
	is_selected = false

	if highlight_tween:
		highlight_tween.kill()

	highlight_tween = create_tween()
	highlight_tween.set_loops()
	highlight_tween.set_ease(Tween.EASE_IN_OUT)
	highlight_tween.set_trans(Tween.TRANS_SINE)

	var scale_up = base_sprite_scale * 1.3
	var scale_down = base_sprite_scale * 1.1

	highlight_tween.tween_property(sprite, "scale", scale_up, 0.6)
	highlight_tween.parallel().tween_property(sprite, "modulate", Color(1.3, 1.25, 0.7, 1.0), 0.6)
	highlight_tween.parallel().tween_property(self, "glow_scale", 1.2, 0.6)

	highlight_tween.tween_property(sprite, "scale", scale_down, 0.6)
	highlight_tween.parallel().tween_property(sprite, "modulate", Color(1.1, 1.05, 0.85, 1.0), 0.6)
	highlight_tween.parallel().tween_property(self, "glow_scale", 1.0, 0.6)

func select():
	is_selected = true
	if highlight_tween:
		highlight_tween.kill()

	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE

	highlight_tween = create_tween()
	highlight_tween.set_ease(Tween.EASE_OUT)
	highlight_tween.set_trans(Tween.TRANS_BOUNCE)
	highlight_tween.tween_property(sprite, "scale", base_sprite_scale * 1.5, 0.15)
	highlight_tween.set_ease(Tween.EASE_OUT)
	highlight_tween.set_trans(Tween.TRANS_SINE)
	highlight_tween.tween_property(sprite, "scale", base_sprite_scale * 1.35, 0.15)

func deselect():
	is_selected = false
	if highlight_tween:
		highlight_tween.kill()
	sprite.self_modulate = Color.WHITE
	sprite.scale = base_sprite_scale
	glow_scale = 1.0
	is_highlighted = false
	queue_redraw()

func reset():
	juice_extracted = 0.0
	sprite.modulate = fruit_colors[fruit_index]
	sprite.scale = base_sprite_scale
	glow_scale = 1.0
	is_highlighted = false
	is_selected = false
	queue_redraw()

func is_clicked(click_pos):
	var local_pos = to_local(click_pos)
	var click_distance = local_pos.length()
	return click_distance < 100

func update_juice_extracted(amount: float):
	juice_extracted = clamp(amount, 0.0, 1.0)
	var white = Color.WHITE
	var grey = Color(0.5, 0.5, 0.5, 1.0)
	var desaturated_color = white.lerp(grey, juice_extracted)
	sprite.modulate = desaturated_color

func _draw():
	if is_highlighted:
		var glow_radius = 110.0 * glow_scale
		var glow_color = Color(1.0, 0.95, 0.4, 0.3)
		draw_circle(Vector2.ZERO, glow_radius, glow_color)

		var outer_glow = Color(1.0, 0.85, 0.0, 0.1)
		draw_circle(Vector2.ZERO, glow_radius * 1.3, outer_glow)

func _process(_delta):
	if is_highlighted:
		queue_redraw()
