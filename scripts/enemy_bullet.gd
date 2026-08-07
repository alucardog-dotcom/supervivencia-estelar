class_name EnemyBullet
extends Area2D

const IMPACT_SCENE := preload("res://scenes/explosion.tscn")

@export var speed: float = 320.0
@export var ground_y: float = 582.0

@onready var visual_root: Node2D = $VisualRoot
@onready var glow: ColorRect = $VisualRoot/Glow

var direction := Vector2.DOWN
var pulse_time := 0.0


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("enemy_projectiles")
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle() - PI * 0.5


func _process(delta: float) -> void:
	pulse_time += delta
	var pulse := 1.22 if int(pulse_time * 16.0) % 2 == 0 else 1.0
	visual_root.scale = Vector2.ONE * pulse
	glow.modulate.a = 0.7 if pulse > 1.0 else 1.0

	global_position += direction * speed * delta

	if direction.y > 0.0 and global_position.y >= ground_y:
		create_ground_impact()
		return

	var viewport_width := get_viewport_rect().size.x
	var viewport_height := get_viewport_rect().size.y

	if (
		global_position.y > viewport_height + 30.0
		or global_position.x < -30.0
		or global_position.x > viewport_width + 30.0
	):
		queue_free()


func create_ground_impact() -> void:
	var impact := IMPACT_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(impact)
	impact.global_position = Vector2(global_position.x, ground_y)
	impact.scale = Vector2.ONE * 0.32
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()
