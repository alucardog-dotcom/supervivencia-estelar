extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const SHEENA_TEST_ATLAS := preload(
	"res://assets/sprites/player/sheena_test/sheena_player_atlas_recolored.png"
)
const AIM_DOWN_DIAGONAL_ATLAS := preload(
	"res://assets/sprites/player/commando/crouch_aim_down_red.png"
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
const ACTIVE_RELOAD_WINDOW := 0.35
const ACTIVE_RELOAD_TRIPLE_DURATION := 5.0
const ACTIVE_RELOAD_MIN_RATIO := 0.35
const ACTIVE_RELOAD_MAX_RATIO := 0.68

signal health_changed(current_health: int)
signal died
signal ammo_changed(current_ammo: int, magazine_size: int)

@export var speed: float = 288.0
@export var jump_velocity: float = -690.0
@export var gravity: float = 1850.0
@export var movement_response: float = 8.0
@export var crouch_transition_speed: float = 14.0
@export var horizontal_margin: float = 32.0
@export var bullet_scene: PackedScene
@export var max_health: int = 3
@export var invulnerability_time: float = 1.0
@export var magazine_size: int = 30
@export var reload_duration: float = 2.5

@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle_flash: Node2D = $Muzzle/MuzzleFlash
@onready var muzzle_flash_timer: Timer = $MuzzleFlashTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var active_reload_start_timer: Timer = $ActiveReloadStartTimer
@onready var active_reload_timer: Timer = $ActiveReloadTimer
@onready var unlimited_ammo_timer: Timer = $UnlimitedAmmoTimer
@onready var triple_shot_timer: Timer = $TripleShotTimer
@onready var powerup_invulnerability_timer: Timer = $PowerupInvulnerabilityTimer
@onready var reload_bar: ProgressBar = $ReloadBar
@onready var reload_label: Label = $ReloadLabel
@onready var shot_sound: AudioStreamPlayer2D = $ShotSound
@onready var reload_sound: AudioStreamPlayer2D = $ReloadSound
@onready var active_reload_success_sound: AudioStreamPlayer2D = $ActiveReloadSuccessSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound

var health: int
var is_invulnerable := false
var facing_direction := 1.0
var current_ammo: int
var is_reloading := false
var active_reload_available := false
var reload_requested_by_controller := false
var is_crouching := false
var crouch_amount := 0.0
var aiming_up := false
var aiming_down_diagonal := false
var aim_down_direction := 1.0
var floor_y := 0.0
var aim_direction := Vector2.RIGHT
var unlimited_ammo_active := false
var triple_shot_active := false
var powerup_invulnerable_active := false
var bullet_speed_multiplier := 1.0
var bullet_size_multiplier := 1.0
var powerup_duration_multiplier := 1.0
var active_reload_window_multiplier := 1.0


func _ready() -> void:
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	frames.add_animation(&"aim_down_diagonal")
	frames.set_animation_loop(&"aim_down_diagonal", true)
	frames.set_animation_speed(&"aim_down_diagonal", 8.0)
	for column in range(6):
		var down_frame := AtlasTexture.new()
		down_frame.atlas = AIM_DOWN_DIAGONAL_ATLAS
		down_frame.region = Rect2(column * 64, 0, 64, 64)
		frames.add_frame(&"aim_down_diagonal", down_frame)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var grounded := is_grounded()
	is_crouching = Input.is_action_pressed("crouch") and grounded
	aiming_down_diagonal = grounded and is_crouching and not is_zero_approx(direction)
	if aiming_down_diagonal:
		aim_down_direction = 1.0 if direction > 0.0 else -1.0
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

	var target_velocity_x := (
		0.0
		if is_crouching and not aiming_down_diagonal
		else direction * speed
	)
	var interpolation_factor := 1.0 - exp(-movement_response * delta)
	velocity.x = lerpf(velocity.x, target_velocity_x, interpolation_factor)
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
	var crouch_target := 1.0 if is_crouching else 0.0
	crouch_amount = move_toward(
		crouch_amount,
		crouch_target,
		crouch_transition_speed * delta
	)
	update_collision_shape()
	update_aim_direction(direction, grounded)

	var is_shooting := (
		Input.is_action_pressed("shoot")
		and not is_reloading
		and (unlimited_ammo_active or current_ammo > 0)
	)

	update_visual(is_shooting, direction, grounded)

	var reload_requested := Input.is_action_just_pressed("reload")
	if reload_requested_by_controller:
		reload_requested = true
		reload_requested_by_controller = false

	if reload_requested:
		if is_reloading:
			attempt_active_reload()
		else:
			start_reload()

	if is_shooting and fire_timer.is_stopped():
		shoot()
		fire_timer.start()

	if is_reloading:
		reload_bar.value = reload_duration - reload_timer.time_left

	update_powerup_visual()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventJoypadButton
		and event.button_index == JOY_BUTTON_RIGHT_SHOULDER
		and event.pressed
	):
		reload_requested_by_controller = true
		get_viewport().set_input_as_handled()


func is_grounded() -> bool:
	return global_position.y >= floor_y - 0.5 and velocity.y >= 0.0


func start_jump() -> void:
	if is_grounded() and not is_crouching:
		velocity.y = jump_velocity


func update_collision_shape() -> void:
	var rectangle := collision_shape.shape as RectangleShape2D

	rectangle.size = Vector2(
		lerpf(36.0, 50.0, crouch_amount),
		lerpf(86.0, 44.0, crouch_amount)
	)
	collision_shape.position = Vector2(
		0.0,
		lerpf(4.0, 25.0, crouch_amount)
	)


func update_aim_direction(
	movement_direction: float,
	grounded: bool
) -> void:
	var aiming_diagonally := (
		aiming_up
		and grounded
		and not is_zero_approx(movement_direction)
	)

	if aiming_down_diagonal:
		aim_direction = Vector2(aim_down_direction, 1.0).normalized()
		muzzle.position = Vector2(18.0 * aim_down_direction, 16.0)
		muzzle.rotation = PI * 0.75 * aim_down_direction
	elif aiming_diagonally:
		aim_direction = Vector2(facing_direction, -1.0).normalized()
		muzzle.position = Vector2(36.0 * facing_direction, -38.0)
		muzzle.rotation = PI * 0.25 * facing_direction
	elif aiming_up:
		aim_direction = Vector2.UP
		muzzle.position = Vector2(0.0, -52.0)
		muzzle.rotation = 0.0
	elif is_crouching:
		aim_direction = Vector2(facing_direction, 0.0)
		muzzle.position = Vector2(45.0 * facing_direction, 37.0)
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
	animated_sprite.position = Vector2(0.0, 4.0)
	var state := "idle"

	if aiming_down_diagonal:
		state = "aim_down_diagonal"
		animated_sprite.flip_h = aim_down_direction < 0.0
		animated_sprite.position = Vector2(0.0, -3.0)
	elif is_crouching:
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
	bullet.set("speed", float(bullet.get("speed")) * bullet_speed_multiplier)
	bullet.scale = Vector2.ONE * bullet_size_multiplier

	if bullet.has_method("setup"):
		bullet.call("setup", direction)


func start_reload() -> void:
	if unlimited_ammo_active or current_ammo >= magazine_size:
		return

	is_reloading = true
	active_reload_available = false
	active_reload_timer.stop()
	reload_sound.play()
	reload_bar.value = 0.0
	reload_bar.show()
	reload_label.show()
	reload_label.text = "RELOADING"
	reload_label.add_theme_color_override("font_color", Color.WHITE)
	reload_timer.start()
	active_reload_start_timer.start(
		reload_duration * randf_range(
			ACTIVE_RELOAD_MIN_RATIO,
			ACTIVE_RELOAD_MAX_RATIO
		)
	)


func attempt_active_reload() -> void:
	if not active_reload_available:
		start_reload()
		return

	active_reload_available = false
	active_reload_timer.stop()
	active_reload_start_timer.stop()
	reload_timer.stop()
	current_ammo = magazine_size
	is_reloading = false
	reload_bar.hide()
	reload_label.hide()
	activate_triple_shot(ACTIVE_RELOAD_TRIPLE_DURATION)
	active_reload_success_sound.play()
	ammo_changed.emit(current_ammo, magazine_size)


func take_damage(amount: int) -> void:
	if is_invulnerable or powerup_invulnerable_active:
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
	invulnerability_timer.start(invulnerability_time)


func give_extra_life(maximum_health: int) -> bool:
	if health >= maximum_health:
		return false

	health = mini(health + 1, maximum_health)
	health_changed.emit(health)
	return true


func refill_ammo() -> void:
	if current_ammo >= magazine_size:
		return
	is_reloading = false
	active_reload_available = false
	active_reload_start_timer.stop()
	active_reload_timer.stop()
	reload_timer.stop()
	reload_bar.hide()
	reload_label.hide()
	current_ammo = magazine_size
	ammo_changed.emit(current_ammo, magazine_size)


func activate_unlimited_ammo(duration: float) -> void:
	unlimited_ammo_active = true
	is_reloading = false
	active_reload_available = false
	active_reload_start_timer.stop()
	active_reload_timer.stop()
	reload_timer.stop()
	reload_bar.hide()
	reload_label.hide()
	current_ammo = magazine_size
	unlimited_ammo_timer.start(duration * powerup_duration_multiplier)
	ammo_changed.emit(-1, -1)


func activate_triple_shot(duration: float) -> void:
	triple_shot_active = true
	triple_shot_timer.start(duration * powerup_duration_multiplier)


func activate_powerup_invulnerability(duration: float) -> void:
	powerup_invulnerable_active = true
	powerup_invulnerability_timer.start(
		duration * powerup_duration_multiplier
	)


func get_unlimited_ammo_time_left() -> float:
	return unlimited_ammo_timer.time_left if unlimited_ammo_active else 0.0


func get_triple_shot_time_left() -> float:
	return triple_shot_timer.time_left if triple_shot_active else 0.0


func get_powerup_invulnerability_time_left() -> float:
	return (
		powerup_invulnerability_timer.time_left
		if powerup_invulnerable_active
		else 0.0
	)


func update_powerup_visual() -> void:
	if powerup_invulnerable_active:
		var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.012) * 0.18
		animated_sprite.modulate = Color(0.48, 0.9, 1.0, pulse)
	elif is_invulnerable:
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
	else:
		animated_sprite.modulate = Color.WHITE


func can_apply_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"reload_speed":
			return reload_duration > 1.21
		"bullet_speed":
			return bullet_speed_multiplier < 1.99
		"magazine_size":
			return magazine_size < 60
		"bullet_size":
			return bullet_size_multiplier < 1.29
		"move_speed":
			return speed < 431.0
		"fire_rate":
			return fire_timer.wait_time > 0.111
		"powerup_duration":
			return powerup_duration_multiplier < 1.99
		"active_reload_window":
			return active_reload_window_multiplier < 1.74
		"recovery_window":
			return invulnerability_time < 1.99
		"jump_boost":
			return jump_velocity > -899.0
		"field_repair":
			return health < 5

	return false


func apply_upgrade(upgrade_id: String) -> bool:
	if not can_apply_upgrade(upgrade_id):
		return false

	match upgrade_id:
		"reload_speed":
			reload_duration = maxf(1.2, reload_duration * 0.90)
			reload_timer.wait_time = reload_duration
			reload_bar.max_value = reload_duration
		"bullet_speed":
			bullet_speed_multiplier = minf(
				2.0,
				bullet_speed_multiplier * 1.10
			)
		"magazine_size":
			magazine_size = mini(60, ceili(magazine_size * 1.10))
			current_ammo = magazine_size
			ammo_changed.emit(current_ammo, magazine_size)
		"bullet_size":
			bullet_size_multiplier = minf(
				1.30,
				bullet_size_multiplier * 1.03
			)
		"move_speed":
			speed = minf(432.0, speed * 1.05)
		"fire_rate":
			fire_timer.wait_time = maxf(0.11, fire_timer.wait_time * 0.95)
		"powerup_duration":
			powerup_duration_multiplier = minf(
				2.0,
				powerup_duration_multiplier * 1.10
			)
		"active_reload_window":
			active_reload_window_multiplier = minf(
				1.75,
				active_reload_window_multiplier * 1.15
			)
		"recovery_window":
			invulnerability_time = minf(2.0, invulnerability_time * 1.10)
			invulnerability_timer.wait_time = invulnerability_time
		"jump_boost":
			jump_velocity = maxf(-900.0, jump_velocity * 1.05)
		"field_repair":
			return give_extra_life(5)

	return true


func die() -> void:
	died.emit()
	queue_free()


func _on_invulnerability_timer_timeout() -> void:
	is_invulnerable = false


func _on_muzzle_flash_timer_timeout() -> void:
	muzzle_flash.hide()


func _on_reload_timer_timeout() -> void:
	current_ammo = magazine_size
	is_reloading = false
	active_reload_available = false
	active_reload_start_timer.stop()
	active_reload_timer.stop()
	reload_bar.hide()
	reload_label.hide()
	ammo_changed.emit(current_ammo, magazine_size)


func _on_active_reload_start_timer_timeout() -> void:
	if not is_reloading:
		return
	active_reload_available = true
	reload_label.add_theme_color_override(
		"font_color", Color(0.25, 1.0, 0.45, 1.0)
	)
	active_reload_timer.start(get_active_reload_window())


func _on_active_reload_timer_timeout() -> void:
	active_reload_available = false
	reload_label.add_theme_color_override("font_color", Color.WHITE)


func get_active_reload_window() -> float:
	return ACTIVE_RELOAD_WINDOW * active_reload_window_multiplier


func _on_unlimited_ammo_timer_timeout() -> void:
	unlimited_ammo_active = false
	ammo_changed.emit(current_ammo, magazine_size)


func _on_triple_shot_timer_timeout() -> void:
	triple_shot_active = false


func _on_powerup_invulnerability_timer_timeout() -> void:
	powerup_invulnerable_active = false
