class_name EnemyBullet
extends Area2D

@export var speed: float = 320.0

var direction := Vector2.DOWN


func _ready() -> void:
	add_to_group("projectiles")


func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()


func _process(delta: float) -> void:
	global_position += direction * speed * delta

	var viewport_width := get_viewport_rect().size.x
	var viewport_height := get_viewport_rect().size.y

	if (
		global_position.y > viewport_height + 30.0
		or global_position.x < -30.0
		or global_position.x > viewport_width + 30.0
	):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()
