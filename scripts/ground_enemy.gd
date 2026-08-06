extends Area2D

signal destroyed(score_value: int)

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

@export var enemy_bullet_scene: PackedScene
@export var base_speed: float = 105.0
@export var speed_per_level: float = 8.0
@export var stop_distance: float = 250.0
@export var base_fire_interval: float = 2.4
@export var score_value: int = 200

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_timer: Timer = $FireTimer
@onready var shot_sound: AudioStreamPlayer2D = $ShotSound

var speed := 105.0
var direction := 1.0
var difficulty_level := 0
var is_destroying := false
var bob_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	fire_timer.timeout.connect(shoot)
	start_fire_timer()


func spawn_from_side(side: int) -> void:
	direction = 1.0 if side < 0 else -1.0
	global_position = Vector2(
		-58.0 if side < 0 else 1210.0,
		546.0
	)
	update_animation()


func apply_difficulty(level: int) -> void:
	difficulty_level = level
	speed = base_speed + speed_per_level * level


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(player):
		return

	direction = signf(player.global_position.x - global_position.x)
	update_animation()

	if absf(player.global_position.x - global_position.x) > stop_distance:
		global_position.x += direction * speed * delta

	bob_time += delta
	animated_sprite.position.y = (
		-2.0 if int(bob_time * 8.0) % 2 == 0 else 0.0
	)


func update_animation() -> void:
	var animation := &"walk_right" if direction > 0.0 else &"walk_left"

	if animated_sprite.animation != animation:
		animated_sprite.play(animation)


func start_fire_timer() -> void:
	fire_timer.wait_time = maxf(
		0.9,
		base_fire_interval - difficulty_level * 0.1
	) * randf_range(0.85, 1.15)
	fire_timer.start()


func shoot() -> void:
	if is_destroying or enemy_bullet_scene == null:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(player):
		return

	var shot_direction := signf(
		player.global_position.x - global_position.x
	)
	var fires_low := randf() < 0.45
	var height_offset := 19.0 if fires_low else -29.0
	var bullet := enemy_bullet_scene.instantiate() as EnemyBullet

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + Vector2(
		shot_direction * 43.0,
		height_offset
	)
	bullet.setup(Vector2(shot_direction, 0.0))
	shot_sound.play()
	start_fire_timer()


func destroy(award_points := true) -> void:
	if is_destroying:
		return

	is_destroying = true
	destroyed.emit(score_value if award_points else 0)

	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position + Vector2(0.0, -22.0)
	explosion.scale = Vector2.ONE * 0.8

	if get_tree().current_scene.has_method("shake_camera"):
		get_tree().current_scene.call("shake_camera", 3.5, 0.14)

	queue_free()


func _on_area_entered(area: Area2D) -> void:
	area.queue_free()
	destroy()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		destroy(false)
