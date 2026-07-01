extends Node2D

var particles = []

class Particle:
	var position: Vector2
	var velocity: Vector2
	var color: Color
	var lifetime: float
	var max_lifetime: float
	var size_start: float
	var size_end: float
	var rotation_speed: float
	var current_rotation: float

	func _init(pos: Vector2, vel: Vector2, col: Color, life: float, size: float):
		position = pos
		velocity = vel
		color = col
		lifetime = life
		max_lifetime = life
		size_start = size
		size_end = size * 0.3
		rotation_speed = randf_range(-TAU, TAU)
		current_rotation = 0.0

func burst(position: Vector2, color: Color, count: int):
	for i in range(count):
		var angle = randf() * TAU
		var speed = randf_range(120, 250)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(0.5, 0.8)
		var size = randf_range(2.5, 4.5)

		var particle = Particle.new(position, velocity, color, lifetime, size)
		particles.append(particle)

func _process(delta):
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.lifetime -= delta
		p.position += p.velocity * delta
		p.velocity.y += 100 * delta
		p.velocity *= 0.98
		p.current_rotation += p.rotation_speed * delta

		if p.lifetime <= 0:
			particles.remove_at(i)

	if particles.size() > 0:
		queue_redraw()

func _draw():
	for p in particles:
		var alpha = p.lifetime / p.max_lifetime
		var size = lerp(p.size_end, p.size_start, alpha)
		var draw_color = p.color
		draw_color.a = alpha

		draw_circle(p.position, size, draw_color)

		var highlight_color = draw_color.lightened(0.3)
		draw_circle(p.position, size * 0.4, highlight_color)
