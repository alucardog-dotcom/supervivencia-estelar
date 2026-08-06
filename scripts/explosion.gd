extends Node2D

@export var lifetime: float = 0.42
@export var particle_count: int = 18

var elapsed_time := 0.0
var particle_positions: Array[Vector2] = []
var particle_velocities: Array[Vector2] = []
var particle_colors: Array[Color] = []


func _ready() -> void:
	var colors := [
		Color("fff0a0"),
		Color("ff9d35"),
		Color("ff3d25"),
		Color("a443ff")
	]

	for index in range(particle_count):
		var angle := randf_range(0.0, TAU)
		var particle_speed := randf_range(70.0, 180.0)

		particle_positions.append(Vector2.ZERO)
		particle_velocities.append(
			Vector2.from_angle(angle) * particle_speed
		)
		particle_colors.append(colors[index % colors.size()])

	queue_redraw()


func _process(delta: float) -> void:
	elapsed_time += delta

	for index in range(particle_positions.size()):
		particle_positions[index] += (
			particle_velocities[index] * delta
		)
		particle_velocities[index] *= 0.9

	queue_redraw()

	if elapsed_time >= lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(elapsed_time / lifetime, 0.0, 1.0)
	var center_size := lerpf(20.0, 2.0, progress)
	var center_color := Color(1.0, 0.85, 0.35, 1.0 - progress)

	draw_rect(
		Rect2(
			Vector2(-center_size, -center_size) * 0.5,
			Vector2(center_size, center_size)
		),
		center_color
	)

	for index in range(particle_positions.size()):
		var particle_size := 6.0 if index % 3 == 0 else 4.0
		var position := particle_positions[index].snapped(
			Vector2(2.0, 2.0)
		)
		var color := particle_colors[index]
		color.a = 1.0 - progress

		draw_rect(
			Rect2(
				position - Vector2.ONE * particle_size * 0.5,
				Vector2.ONE * particle_size
			),
			color
		)
