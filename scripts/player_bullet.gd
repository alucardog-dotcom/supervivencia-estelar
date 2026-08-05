extends Area2D

@export var speed: float = 500.0


func _ready() -> void:
	add_to_group("projectiles")


func _process(delta: float) -> void:
	global_position.y -= speed * delta

	if global_position.y < -20.0:
		queue_free()
