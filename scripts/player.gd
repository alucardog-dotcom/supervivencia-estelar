extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const SHEENA_TEST_ATLAS := preload(
	"res://assets/sprites/player/sheena_test/sheena_player_atlas_recolored.png"
)
const SHEENA_FRAME_SIZE := 64
const SHEENA_ANIMATIONS := {
	&"idle": {"row": 0, "frames": 1, "speed": 1.0},
	&"walk": {"row": 1, "frames": 6, "speed": 10.0},
	&"shoot_up": {"row": 2, "frames": 1, "speed": 1.0},
	&"walk_shoot_diagonal": {"row": 3, "frames": 6, "speed": 10.0},
	&"jump": {"row": 4, "frames": 4, "speed": 10.0},
	&"jump_up": {"row": 2, "frames": 1, "speed": 1.0},
	&"crouch": {"row": 5, "frames": 1, "speed": 1.0},
}

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
@onready var unlimited_ammo_timer: Timer = $UnlimitedAmmoTimer
@onready var triple_shot_timer: Timer = $TripleShotTimer
@onready var reload_bar: ProgressBar = $ReloadBar
@onready var reload_label: Label = $ReloadLabel
@onready var shot_sound: AudioStreamPlayer2D = $ShotSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound

var health: int
var is_invulnerable := false
var facing_direction := 1.0
var current_ammo: int
var is_reloading := false
var is_crouching := false
var aiming_up := false
var floor_y := 0.0
var aim_direction := Vector2.RIGHT
var unlimited_ammo_active := false
var triple_shot_active := false


func _ready() -> void:
	add_to_group("player")
	setup_sheena_test_frames()
	health = max_health
	floor_y = global_position.y
	invulnerability_timer.wait_time = invulnerability_time
	current_ammo = magazine_size
	reload_timer.wait_time = reload_duration
	reload_bar.max_value = reload_duration
	reload_bar.hide()
	reload_label.hide()
	update_visual(false, 0.0, true)


func setup_sheena_test_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	for animation_name: StringName in SHEENA_ANIMATIONS:
		var animation_data: Dictionary = SHEENA_ANIMATIONS[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(
			animation_name,
			float(animation_data["speed"])
		)

		for column in range(int(animation_data["frames"])):
			var frame := AtlasTexture.new()
			frame.atlas = SHEENA_TEST_ATLAS
			frame.region = Rect2(
				column * SHEENA_FRAME_SIZE,
				int(animation_data["row"]) * SHEENA_FRAME_SIZE,
				SHEENA_FRAME_SIZE,
				SHEENA_FRAME_SIZE
			)
			frames.add_frame(animation_name, frame)

	animated_sprite.sprite_frames = frames


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
	update_aim_direction(direction, grounded)

	var is_shooting := (
		Input.is_action_pressed("shoot")
		and not is_reloading
		and (unlimited_ammo_active or current_ammo > 0)
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


func update_aim_direction(
	movement_direction: float,
	grounded: bool
) -> void:
	var aiming_diagonally := (
		aiming_up
		and grounded
		and not is_zero_approx(movement_direction)
	)

	if aiming_diagonally:
		aim_direction = Vector2(facing_direction, -1.0).normalized()
		muzzle.position = Vector2(36.0 * facing_direction, -38.0)
		muzzle.rotation = PI * 0.25 * facing_direction
	elif aiming_up:
		aim_direction = Vector2.UP
		muzzle.position = Vector2(0.0, -52.0)
		muzzle.rotation = 0.0
	elif is_crouching:
		aim_direction = Vector2(facing_direction, 0.0)
		muzzle.position = Vector2(45.0 * facing_direction, 4.0)
		muzzle.rotation = PI * 0.5 * facing_direction
	else:
		aim_direction = Vector2(facing_direction, 0.0)
		muzzle.position = Vector2(45.0 * facing_direction, -8.0)
		muzzle.rotation = PI * 0.5 * facing_direction


func update_visual(
	is_shooting: bool,
	movement_direction: float,
	grounded: bool
) -> void:
	animated_sprite.flip_h = facing_direction < 0.0
	var state := "idle"

	if is_crouching:
		state = "crouch"
		animated_sprite.flip_h = facing_direction > 0.0
	elif not grounded:
		state = "jump_up" if aiming_up else "jump"
	elif aiming_up and not is_zero_approx(movement_direction):
		state = "walk_shoot_diagonal"
	elif aiming_up:
		state = "shoot_up"
	elif not is_zero_approx(movement_direction):
		state = "walk"

	var target_animation := StringName(state)

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

	if not is_shooting:
		muzzle_flash.hide()


func shoot() -> void:
	if is_reloading or (not unlimited_ammo_active and current_ammo <= 0):
		return

	spawn_bullet(aim_direction)

	if triple_shot_active:
		spawn_bullet(aim_direction.rotated(deg_to_rad(-12.0)))
		spawn_bullet(aim_direction.rotated(deg_to_rad(12.0)))

	muzzle_flash.show()
	muzzle_flash_timer.start()
	shot_sound.play()

	if unlimited_ammo_active:
		return

	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)

	if current_ammo <= 0:
		start_reload()


func spawn_bullet(direction: Vector2) -> void:
	var bullet := bullet_scene.instantiate() as Area2D
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.call("setup", direction)


func start_reload() -> void:
	if unlimited_ammo_active:
		return

	is_reloading = true
	reload_bar.value = 0.0
	reload_bar.show()
	reload_label.show()
	reload_timer.start()


func take_damage(amount: int) -> void:
	if is_invulnerable:
		return

	hurt_sound.play()

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


func give_extra_life(maximum_health: int) -> bool:
	if health >= maximum_health:
		return false

	health = mini(health + 1, maximum_health)
	health_changed.emit(health)
	return true


func activate_unlimited_ammo(duration: float) -> void:
	unlimited_ammo_active = true
	is_reloading = false
	reload_timer.stop()
	reload_bar.hide()
	reload_label.hide()
	current_ammo = magazine_size
	unlimited_ammo_timer.start(duration)
	ammo_changed.emit(-1, -1)


func activate_triple_shot(duration: float) -> void:
	triple_shot_active = true
	triple_shot_timer.start(duration)


func get_unlimited_ammo_time_left() -> float:
	return unlimited_ammo_timer.time_left if unlimited_ammo_active else 0.0


func get_triple_shot_time_left() -> float:
	return triple_shot_timer.time_left if triple_shot_active else 0.0


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


func _on_unlimited_ammo_timer_timeout() -> void:
	unlimited_ammo_active = false
	ammo_changed.emit(current_ammo, magazine_size)


func _on_triple_shot_timer_timeout() -> void:
	triple_shot_active = false
