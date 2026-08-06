extends Area2D

signal destroyed

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

enum FireMode {
	RANDOM,
	AIMED
}

@export var min_x: float = 60.0
@export var max_x: float = 1092.0
@export var enemy_bullet_scene: PackedScene
@export var fire_mode: FireMode = FireMode.RANDOM
@export var hover_amplitude: float = 18.0
@export var hover_frequency: float = 0.6

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
var hover_center_y: float
var hover_time := 0.0
var hover_phase: float
var actual_hover_amplitude: float
var actual_hover_frequency: float
var hover_initialized := false
var is_destroying := false


func _ready() -> void:
	add_to_group("enemies")

	if speed <= 0.0:
		apply_difficulty(0)

	direction = [-1.0, 1.0].pick_random()
	hover_phase = randf_range(0.0, TAU)
	actual_hover_amplitude = hover_amplitude * randf_range(
		0.85,
		1.15
	)
	actual_hover_frequency = hover_frequency * randf_range(
		0.9,
		1.1
	)
	start_fire_timer()


func _process(delta: float) -> void:
	if not hover_initialized:
		hover_center_y = global_position.y
		hover_initialized = true

	hover_time += delta
	global_position.x += direction * speed * delta
	global_position.y = hover_center_y + sin(
		hover_time * TAU * actual_hover_frequency
		+ hover_phase
	) * actual_hover_amplitude

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
	if is_destroying:
		return

	is_destroying = true
	area.queue_free()
	destroyed.emit()

	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position

	if get_tree().current_scene.has_method("shake_camera"):
		get_tree().current_scene.call(
			"shake_camera",
			3.0,
			0.12
		)

	queue_free()
