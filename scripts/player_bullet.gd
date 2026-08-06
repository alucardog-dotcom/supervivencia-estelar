extends Area2D

@export var speed: float = 500.0

@onready var visual_root: Node2D = $VisualRoot
@onready var core: ColorRect = $VisualRoot/Core

var direction := Vector2.UP
var pulse_time := 0.0


func _ready() -> void:
	add_to_group("projectiles")


func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle() + PI * 0.5


func _process(delta: float) -> void:
	pulse_time += delta
	var pulse := 1.25 if int(pulse_time * 22.0) % 2 == 0 else 1.0
	visual_root.scale.x = pulse
	core.modulate.a = 0.82 if pulse > 1.0 else 1.0

	global_position += direction * speed * delta

	var viewport_width := get_viewport_rect().size.x

	if (
		global_position.y < -20.0
		or global_position.x < -20.0
		or global_position.x > viewport_width + 20.0
	):
		queue_free()
