extends Area2D

signal destroyed(score_value: int)

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

@export var base_speed: float = 205.0
@export var speed_per_level: float = 13.0
@export var score_value: int = 300

@onready var sprite: Sprite2D = $Sprite2D
@onready var scream_sound: AudioStreamPlayer2D = $ScreamSound

var speed := 205.0
var direction := 1.0
var is_destroying := false
var run_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	process_mode = Node.PROCESS_MODE_PAUSABLE


func spawn_from_side(side: int) -> void:
	direction = 1.0 if side < 0 else -1.0
	global_position = Vector2(
		-70.0 if side < 0 else 1222.0,
		546.0
	)
	update_visual()
	scream_sound.play()


func apply_difficulty(level: int) -> void:
	speed = base_speed + speed_per_level * level


func _process(delta: float) -> void:
	if is_destroying:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(player):
		return

	var horizontal_distance := player.global_position.x - global_position.x

	if not is_zero_approx(horizontal_distance):
		direction = signf(horizontal_distance)

	global_position.x += direction * speed * delta
	run_time += delta
	update_visual()


func update_visual() -> void:
	sprite.flip_h = direction < 0.0
	var step := int(run_time * 14.0) % 2
	sprite.position.y = -3.0 if step == 0 else 0.0
	sprite.rotation = direction * (0.035 if step == 0 else -0.02)


func destroy(award_points := true) -> void:
	if is_destroying:
		return

	is_destroying = true
	destroyed.emit(score_value if award_points else 0)

	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position + Vector2(0.0, -18.0)
	explosion.scale = Vector2.ONE * 1.45

	if get_tree().current_scene.has_method("shake_camera"):
		get_tree().current_scene.call("shake_camera", 8.0, 0.3)

	queue_free()


func _on_area_entered(area: Area2D) -> void:
	area.queue_free()
	destroy()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.call("take_damage", 2)
		destroy(false)
