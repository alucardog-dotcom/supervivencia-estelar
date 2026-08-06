extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

signal health_changed(current_health: int)
signal died
signal ammo_changed(current_ammo: int, magazine_size: int)

@export var speed: float = 288.0
@export var jump_velocity: float = -690.0
@export var gravity: float = 1850.0
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
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
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
var is_crouching := false
var aiming_up := false
var floor_y := 0.0
var aim_direction := Vector2.RIGHT


func _ready() -> void:
	add_to_group("player")
	health = max_health
	floor_y = global_position.y
	invulnerability_timer.wait_time = invulnerability_time
	current_ammo = magazine_size
	reload_timer.wait_time = reload_duration
	reload_bar.max_value = reload_duration
	reload_bar.hide()
	reload_label.hide()
	update_visual(false, 0.0, true)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var grounded := is_grounded()
	is_crouching = Input.is_action_pressed("crouch") and grounded
	aiming_up = Input.is_action_pressed("aim_up") and not is_crouching

	if not is_zero_approx(direction) and not is_crouching:
		facing_direction = 1.0 if direction > 0.0 else -1.0

	if Input.is_action_just_pressed("jump"):
		start_jump()
		grounded = is_grounded()

	if grounded:
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta

	velocity.x = 0.0 if is_crouching else direction * speed
	move_and_slide()

	if global_position.y >= floor_y:
		global_position.y = floor_y
		velocity.y = 0.0

	global_position.x = clampf(
		global_position.x,
		horizontal_margin,
		get_viewport_rect().size.x - horizontal_margin
	)

	grounded = is_grounded()
	is_crouching = Input.is_action_pressed("crouch") and grounded
	update_collision_shape()
	update_aim_direction()

	var is_shooting := (
		Input.is_action_pressed("shoot")
		and not is_reloading
		and current_ammo > 0
	)

	update_visual(is_shooting, direction, grounded)

	if is_shooting and fire_timer.is_stopped():
		shoot()
		fire_timer.start()

	if is_reloading:
		reload_bar.value = reload_duration - reload_timer.time_left


func is_grounded() -> bool:
	return global_position.y >= floor_y - 0.5 and velocity.y >= 0.0


func start_jump() -> void:
	if is_grounded() and not is_crouching:
		velocity.y = jump_velocity


func update_collision_shape() -> void:
	var rectangle := collision_shape.shape as RectangleShape2D

	if is_crouching:
		rectangle.size = Vector2(50.0, 44.0)
		collision_shape.position = Vector2(0.0, 25.0)
	else:
		rectangle.size = Vector2(36.0, 86.0)
		collision_shape.position = Vector2(0.0, 4.0)


func update_aim_direction() -> void:
	if aiming_up:
		aim_direction = Vector2.UP
		muzzle.position = Vector2(27.0 * facing_direction, -52.0)
		muzzle.rotation = 0.0
	elif is_crouching:
		aim_direction = Vector2(facing_direction, 0.0)
		muzzle.position = Vector2(45.0 * facing_direction, 4.0)
		muzzle.rotation = PI * 0.5 * facing_direction
	else:
		aim_direction = Vector2(facing_direction, 0.0)
		muzzle.position = Vector2(45.0 * facing_direction, -18.0)
		muzzle.rotation = PI * 0.5 * facing_direction


func update_visual(
	is_shooting: bool,
	movement_direction: float,
	grounded: bool
) -> void:
	var side := "right" if facing_direction > 0.0 else "left"
	var state := "idle_"

	if is_crouching:
		state = "crouch_"
	elif not grounded:
		state = "jump_up_" if aiming_up else "jump_"
	elif aiming_up and not is_zero_approx(movement_direction):
		state = "walk_shoot_up_"
	elif aiming_up:
		state = "shoot_up_"
	elif not is_zero_approx(movement_direction):
		state = "walk_"

	var target_animation := StringName(state + side)

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

	if not is_shooting:
		muzzle_flash.hide()


func shoot() -> void:
	if is_reloading or current_ammo <= 0:
		return

	var bullet := bullet_scene.instantiate() as Area2D
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.call("setup", aim_direction)

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
