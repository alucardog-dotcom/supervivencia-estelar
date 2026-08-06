extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

signal health_changed(current_health: int)
signal died
signal ammo_changed(current_ammo: int, magazine_size: int)

@export var speed: float = 288.0
@export var horizontal_margin: float = 32.0
@export var bullet_scene: PackedScene
@export var max_health: int = 3
@export var invulnerability_time: float = 1.0
@export var magazine_size: int = 20
@export var reload_duration: float = 3.5

@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle_flash: Node2D = $Muzzle/MuzzleFlash
@onready var muzzle_flash_timer: Timer = $MuzzleFlashTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var reload_bar: ProgressBar = $ReloadBar
@onready var reload_label: Label = $ReloadLabel

var health: int
var is_invulnerable := false
var facing_direction := 1.0
var current_ammo: int
var is_reloading := false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	invulnerability_timer.wait_time = invulnerability_time
	current_ammo = magazine_size
	reload_timer.wait_time = reload_duration
	reload_bar.max_value = reload_duration
	reload_bar.hide()
	reload_label.hide()
	update_visual(false, 0.0)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var is_shooting := (
		Input.is_action_pressed("shoot")
		and not is_reloading
		and current_ammo > 0
	)

	if not is_zero_approx(direction):
		facing_direction = 1.0 if direction > 0.0 else -1.0

	velocity = Vector2(direction * speed, 0.0)
	move_and_slide()

	global_position.x = clampf(
		global_position.x,
		horizontal_margin,
		get_viewport_rect().size.x - horizontal_margin
	)

	update_visual(is_shooting, direction)

	if is_shooting and fire_timer.is_stopped():
		shoot()
		fire_timer.start()

	if is_reloading:
		reload_bar.value = reload_duration - reload_timer.time_left


func update_visual(
	is_shooting: bool,
	movement_direction: float
) -> void:
	var side := "right" if facing_direction > 0.0 else "left"
	var state := "idle_"

	if is_shooting and not is_zero_approx(movement_direction):
		state = "walk_shoot_up_"
	elif is_shooting:
		state = "shoot_up_"
	elif not is_zero_approx(movement_direction):
		state = "walk_"

	var target_animation := StringName(state + side)

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

	muzzle.position.x = 27.0 * facing_direction


func shoot() -> void:
	if is_reloading or current_ammo <= 0:
		return

	var bullet := bullet_scene.instantiate() as Area2D
	var bullet_direction := Vector2(
		0.32 * facing_direction,
		-1.0
	)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.call("setup", bullet_direction)

	muzzle_flash.show()
	muzzle_flash_timer.start()

	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)

	if current_ammo <= 0:
		start_reload()


func start_reload() -> void:
	is_reloading = true
	reload_bar.value = 0.0
	reload_bar.show()
	reload_label.show()
	reload_timer.start()


func take_damage(amount: int) -> void:
	if is_invulnerable:
		return

	var impact := EXPLOSION_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position + Vector2(0.0, -22.0)
	impact.scale = Vector2.ONE * 0.55

	if get_tree().current_scene.has_method("shake_camera"):
		get_tree().current_scene.call("shake_camera", 5.0, 0.18)

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


func _on_muzzle_flash_timer_timeout() -> void:
	muzzle_flash.hide()


func _on_reload_timer_timeout() -> void:
	current_ammo = magazine_size
	is_reloading = false
	reload_bar.hide()
	reload_label.hide()
	ammo_changed.emit(current_ammo, magazine_size)
