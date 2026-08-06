extends Area2D

signal destroyed(drop_position: Vector2)

@export var speed := 125.0
@export var bob_amplitude := 8.0
@export var bob_frequency := 1.8

var direction := 1.0
var center_y := 150.0
var elapsed := 0.0
var is_destroying := false


func _ready() -> void:
	add_to_group("powerup_carriers")


func spawn_from_side(side: int, spawn_y: float) -> void:
	direction = 1.0 if side < 0 else -1.0
	center_y = spawn_y
	global_position = Vector2(-70.0 if side < 0 else 1222.0, spawn_y)
	$Sprite2D.flip_h = direction < 0.0


func _process(delta: float) -> void:
	elapsed += delta
	global_position.x += direction * speed * delta
	global_position.y = center_y + sin(elapsed * TAU * bob_frequency) * bob_amplitude

	if global_position.x < -100.0 or global_position.x > 1252.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_destroying:
		return

	is_destroying = true
	area.queue_free()
	destroyed.emit(global_position)
	queue_free()
