extends CharacterBody2D

signal health_changed(current_health: int)
signal died

@export var speed: float = 400.0
@export var horizontal_margin: float = 32.0
@export var bullet_scene: PackedScene
@export var max_health: int = 3
@export var invulnerability_time: float = 1.0

@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer

var health: int
var is_invulnerable := false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	invulnerability_timer.wait_time = invulnerability_time


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	velocity = Vector2(direction * speed, 0.0)
	move_and_slide()

	global_position.x = clampf(
		global_position.x,
		horizontal_margin,
		get_viewport_rect().size.x - horizontal_margin
	)

	if Input.is_action_pressed("shoot") and fire_timer.is_stopped():
		shoot()
		fire_timer.start()


func shoot() -> void:
	var bullet := bullet_scene.instantiate() as Area2D

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position


func take_damage(amount: int) -> void:
	if is_invulnerable:
		return

	health -= amount
	health_changed.emit(health)
	print("Vida restante: ", health)

	if health <= 0:
		die()
		return

	is_invulnerable = true
	modulate.a = 0.5
	invulnerability_timer.start()


func die() -> void:
	died.emit()
	queue_free()


func _on_invulnerability_timer_timeout() -> void:
	is_invulnerable = false
	modulate.a = 1.0
