extends Area2D

enum FireMode {
	RANDOM,
	AIMED
}

@export var min_x: float = 60.0
@export var max_x: float = 1092.0
@export var enemy_bullet_scene: PackedScene
@export var fire_mode: FireMode = FireMode.RANDOM

@export var base_speed: float = 220.0
@export var speed_per_level: float = 30.0
@export var base_min_fire_interval: float = 0.9
@export var base_max_fire_interval: float = 1.8

@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer

var speed: float
var min_fire_interval: float
var max_fire_interval: float
var direction: float = 1.0


func _ready() -> void:
	add_to_group("enemies")

	if speed <= 0.0:
		apply_difficulty(0)

	direction = [-1.0, 1.0].pick_random()
	start_fire_timer()


func _process(delta: float) -> void:
	global_position.x += direction * speed * delta

	if global_position.x <= min_x:
		global_position.x = min_x
		direction = 1.0
	elif global_position.x >= max_x:
		global_position.x = max_x
		direction = -1.0


func apply_difficulty(level: int) -> void:
	speed = base_speed + level * speed_per_level

	min_fire_interval = maxf(
		0.22,
		base_min_fire_interval - level * 0.04
	)

	max_fire_interval = maxf(
		0.45,
		base_max_fire_interval - level * 0.07
	)


func start_fire_timer() -> void:
	fire_timer.wait_time = randf_range(
		min_fire_interval,
		max_fire_interval
	)
	fire_timer.start()


func shoot() -> void:
	if enemy_bullet_scene == null:
		push_error("Enemy Bullet Scene no está asignada.")
		return

	var bullet := enemy_bullet_scene.instantiate() as EnemyBullet
	var bullet_direction := Vector2.DOWN

	if fire_mode == FireMode.RANDOM:
		bullet_direction = Vector2(
			randf_range(-0.35, 0.35),
			1.0
		)
	else:
		var player := get_tree().get_first_node_in_group(
			"player"
		) as Node2D

		if is_instance_valid(player):
			bullet_direction = muzzle.global_position.direction_to(
				player.global_position
			)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.setup(bullet_direction)


func _on_fire_timer_timeout() -> void:
	shoot()
	start_fire_timer()


func _on_area_entered(area: Area2D) -> void:
	area.queue_free()
	queue_free()
