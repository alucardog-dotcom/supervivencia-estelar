extends Node2D

const SCORE_PATH := "user://arcade_scores.cfg"
const MAX_SCORES := 5
const SURVIVAL_POINTS_PER_SECOND := 10
const EXTRA_LIFE_SCORE_INTERVAL := 50000
const MAX_PLAYER_HEALTH := 5
const POWERUP_DURATION := 15.0
const HEART_TEXTURE_SIZE := 24
const HEART_DISPLAY_SIZE := 20
const UPGRADE_DEFINITIONS := {
	"reload_speed": {
		"title": "RELOAD DRIVE",
		"description": "Reload time -10% (minimum 1.2s)",
	},
	"bullet_speed": {
		"title": "ACCELERATED ROUNDS",
		"description": "Projectile speed +10% (maximum +100%)",
	},
	"magazine_size": {
		"title": "EXPANDED MAGAZINE",
		"description": "Magazine capacity +10% (maximum 60)",
	},
	"bullet_size": {
		"title": "HEAVY ROUNDS",
		"description": "Projectile size +3% (maximum +30%)",
	},
	"move_speed": {
		"title": "MOBILITY SERVOS",
		"description": "Movement speed +5% (maximum +50%)",
	},
	"fire_rate": {
		"title": "TRIGGER TUNING",
		"description": "Time between shots -5%",
	},
	"powerup_duration": {
		"title": "POWER CELL",
		"description": "Temporary power-ups last 10% longer",
	},
	"active_reload_window": {
		"title": "ACTIVE RELOAD TRAINING",
		"description": "Active reload window +15% (maximum +75%)",
	},
	"recovery_window": {
		"title": "COMBAT RECOVERY",
		"description": "Post-hit protection lasts 10% longer",
	},
	"jump_boost": {
		"title": "KINETIC BOOTS",
		"description": "Jump strength +5% (maximum +30%)",
	},
	"field_repair": {
		"title": "FIELD REPAIR",
		"description": "Restore one heart (maximum five)",
		"selection_weight": 0.4,
	},
}

@export var enemy_scene: PackedScene
@export var aimed_enemy_scene: PackedScene
@export var fast_enemy_scene: PackedScene
@export var ground_enemy_scene: PackedScene
@export var kamikaze_enemy_scene: PackedScene
@export var ambush_enemy_scene: PackedScene
@export var powerup_carrier_scene: PackedScene
@export var powerup_item_scene: PackedScene
@export var initial_max_enemies: int = 3
@export var final_max_enemies: int = 8
@export var base_enemies_per_wave: int = 6
@export var enemies_per_wave_growth: int = 2
@export var wave_break_duration: float = 4.0
@export var ground_enemy_start_wave: int = 3
@export var kamikaze_start_wave: int = 4
@export var ambush_start_wave: int = 5
@export var starting_wave: int = 1

@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var wave_break_timer: Timer = $WaveBreakTimer
@onready var wave_message_timer: Timer = $WaveMessageTimer
@onready var powerup_spawn_timer: Timer = $PowerupSpawnTimer
@onready var camera: Camera2D = $Camera2D
@onready var day_background: TextureRect = $DayBackground
@onready var rain: GPUParticles2D = $Rain
@onready var lightning_flash: ColorRect = $LightningFlash
@onready var status_panel: Panel = $HUD/StatusPanel
@onready var health_label: Label = $HUD/StatusPanel/HealthLabel
@onready var ammo_label: Label = $HUD/StatusPanel/AmmoLabel
@onready var wave_indicator_label: Label = $HUD/WaveIndicatorLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var wave_label: Label = $HUD/WaveLabel
@onready var controls_label: Label = $HUD/ControlsLabel
@onready var powerup_status_label: Label = $HUD/PowerupStatusLabel
@onready var powerup_message_label: Label = $HUD/PowerupMessageLabel
@onready var powerup_flash: ColorRect = $HUD/PowerupFlash
@onready var upgrade_overlay: ColorRect = $HUD/UpgradeOverlay
@onready var upgrade_buttons: Array[Button] = [
	$HUD/UpgradeOverlay/UpgradeRow/Upgrade1,
	$HUD/UpgradeOverlay/UpgradeRow/Upgrade2,
	$HUD/UpgradeOverlay/UpgradeRow/Upgrade3,
]
@onready var game_over_label: Label = $HUD/GameOverLabel
@onready var restart_label: Label = $HUD/RestartLabel
@onready var initials_prompt: Label = $HUD/InitialsPrompt
@onready var initials_input: LineEdit = $HUD/InitialsInput
@onready var leaderboard_label: Label = $HUD/LeaderboardLabel
@onready var game_over_overlay: ColorRect = $HUD/GameOverOverlay
@onready var ground_warning_sound: AudioStreamPlayer = $GroundEnemyWarningSound
@onready var gameplay_music: AudioStreamPlayer = $GameplayMusic
@onready var game_over_music: AudioStreamPlayer = $GameOverMusic
@onready var extra_life_sound: AudioStreamPlayer = $ExtraLifeSound
@onready var powerup_pickup_sound: AudioStreamPlayer = $PowerupPickupSound
@onready var screen_bomb_sound: AudioStreamPlayer = $ScreenBombSound
@onready var invulnerability_sound: AudioStreamPlayer = $InvulnerabilitySound

var elapsed_time := 0.0
var current_score := 0
var next_survival_score_time := 1.0
var difficulty_level := 0
var max_enemies: int
var is_game_over := false
var waiting_for_initials := false
var leaderboard: Array = []
var _leaderboard_online_ready := false
var wave_number := 1
var wave_target := 0
var wave_spawned := 0
var wave_defeated := 0
var wave_active := false
var camera_shake_time := 0.0
var camera_shake_strength := 0.0
var next_extra_life_score := EXTRA_LIFE_SCORE_INTERVAL
var powerup_message_tween: Tween
var choosing_upgrade := false
var current_upgrade_ids: Array[String] = []
var hearts_row: HBoxContainer
var heart_textures: Array[TextureRect] = []
var lightning_countdown := 6.0
var lightning_tween: Tween


func _ready() -> void:
	game_over_label.hide()
	restart_label.hide()
	initials_prompt.hide()
	initials_input.hide()
	leaderboard_label.hide()
	game_over_overlay.hide()
	wave_label.hide()
	powerup_status_label.hide()
	powerup_message_label.hide()
	powerup_flash.hide()
	upgrade_overlay.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_break_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_message_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	powerup_spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	health_label.hide()
	setup_health_hearts()
	_on_player_health_changed(int($Player.get("health")))
	_on_player_ammo_changed(
		int($Player.get("current_ammo")),
		int($Player.get("magazine_size"))
	)

	max_enemies = initial_max_enemies
	wave_number = maxi(1, starting_wave)
	start_gameplay_music()
	load_leaderboard()
	update_score_label()

	if not enemy_spawn_timer.timeout.is_connected(
		_on_enemy_spawn_timer_timeout
	):
		enemy_spawn_timer.timeout.connect(
			_on_enemy_spawn_timer_timeout
		)

	if not wave_break_timer.timeout.is_connected(
		_on_wave_break_timer_timeout
	):
		wave_break_timer.timeout.connect(
			_on_wave_break_timer_timeout
		)

	if not wave_message_timer.timeout.is_connected(
		_on_wave_message_timer_timeout
	):
		wave_message_timer.timeout.connect(
			_on_wave_message_timer_timeout
		)

	if not powerup_spawn_timer.timeout.is_connected(
		_on_powerup_spawn_timer_timeout
	):
		powerup_spawn_timer.timeout.connect(
			_on_powerup_spawn_timer_timeout
		)

	if not initials_input.text_submitted.is_connected(
		_on_initials_input_text_submitted
	):
		initials_input.text_submitted.connect(
			_on_initials_input_text_submitted
		)

	for index in range(upgrade_buttons.size()):
		if not upgrade_buttons[index].pressed.is_connected(
			_on_upgrade_button_pressed.bind(index)
		):
			upgrade_buttons[index].pressed.connect(
				_on_upgrade_button_pressed.bind(index)
			)

	start_wave()
	schedule_powerup_spawn(true)
	show_controls_temporarily()


func show_controls_temporarily() -> void:
	controls_label.text = (
		"KEYS: %s MOVE  %s JUMP  %s CROUCH  %s AIM  %s FIRE  %s RELOAD\n"
		+ "PAD: %s MOVE  %s JUMP  %s CROUCH  %s AIM  %s FIRE  %s RELOAD"
	) % [
		GameSettings.describe_key("move_left") + "/" + GameSettings.describe_key("move_right"),
		GameSettings.describe_key("jump"),
		GameSettings.describe_key("crouch"),
		GameSettings.describe_key("aim_up"),
		GameSettings.describe_key("shoot"),
		GameSettings.describe_key("reload"),
		GameSettings.describe_joypad("move_left") + "/" + GameSettings.describe_joypad("move_right"),
		GameSettings.describe_joypad("jump"),
		GameSettings.describe_joypad("crouch"),
		GameSettings.describe_joypad("aim_up"),
		GameSettings.describe_joypad("shoot"),
		GameSettings.describe_joypad("reload"),
	]

	controls_label.show()
	controls_label.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(controls_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(controls_label.hide)


func create_heart_texture() -> ImageTexture:
	var image := Image.create(
		HEART_TEXTURE_SIZE,
		HEART_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	var center := Vector2(
		HEART_TEXTURE_SIZE * 0.5,
		HEART_TEXTURE_SIZE * 0.42
	)
	var scale_factor := HEART_TEXTURE_SIZE * 0.27
	var heart_color := Color(1.0, 0.23, 0.29, 1.0)

	for y in range(HEART_TEXTURE_SIZE):
		for x in range(HEART_TEXTURE_SIZE):
			var u := (float(x) - center.x) / scale_factor
			var v := (center.y - float(y)) / scale_factor
			var curve := u * u + v * v - 1.0

			if curve * curve * curve - u * u * v * v * v < 0.0:
				image.set_pixel(x, y, heart_color)

	return ImageTexture.create_from_image(image)


func setup_health_hearts() -> void:
	hearts_row = HBoxContainer.new()
	hearts_row.name = "Hearts"
	hearts_row.add_theme_constant_override("separation", 4)

	var heart_texture := create_heart_texture()

	for _index in range(MAX_PLAYER_HEALTH):
		var heart := TextureRect.new()
		heart.texture = heart_texture
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(
			HEART_DISPLAY_SIZE,
			HEART_DISPLAY_SIZE
		)
		hearts_row.add_child(heart)
		heart_textures.append(heart)

	var life_title := $HUD/StatusPanel/LifeTitle as Control
	hearts_row.position = Vector2(
		life_title.offset_right + 8.0,
		life_title.offset_top
		+ (life_title.offset_bottom - life_title.offset_top - HEART_DISPLAY_SIZE) * 0.5
	)
	$HUD/StatusPanel.add_child(hearts_row)


func start_gameplay_music() -> void:
	configure_music_loop(gameplay_music)
	gameplay_music.play()


func configure_music_loop(player: AudioStreamPlayer) -> void:
	var wav_stream := player.stream as AudioStreamWAV

	if wav_stream != null:
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = int(
			round(wav_stream.get_length() * wav_stream.mix_rate)
		)



func start_game_over_music() -> void:
	configure_music_loop(game_over_music)
	game_over_music.volume_db = -30.0
	game_over_music.play()

	var music_transition := create_tween().set_parallel(true)
	music_transition.tween_property(
		gameplay_music,
		"volume_db",
		-35.0,
		0.8
	)
	music_transition.tween_property(
		game_over_music,
		"volume_db",
		-10.0,
		0.8
	)
	music_transition.chain().tween_callback(gameplay_music.stop)


func _process(delta: float) -> void:
	update_camera_shake(delta)
	update_day_night_cycle(delta)
	update_weather(delta)

	if is_game_over or choosing_upgrade or get_tree().paused:
		return

	elapsed_time += delta
	update_powerup_status()

	while elapsed_time >= next_survival_score_time:
		add_score(SURVIVAL_POINTS_PER_SECOND)
		next_survival_score_time += 1.0


func update_day_night_cycle(delta: float) -> void:
	# Wave 1 starts in daylight; by wave 10 the original night is fully visible.
	var night_progress := clampf(float(wave_number - 1) / 9.0, 0.0, 1.0)
	var target_day_alpha := 1.0 - night_progress
	day_background.modulate.a = move_toward(
		day_background.modulate.a,
		target_day_alpha,
		delta * 0.08
	)


func update_weather(delta: float) -> void:
	rain.emitting = wave_number >= 4 and not is_game_over

	if wave_number < 7 or is_game_over:
		lightning_countdown = 6.0
		return

	lightning_countdown -= delta
	if lightning_countdown <= 0.0:
		trigger_lightning()
		lightning_countdown = randf_range(4.0, 10.0)


func trigger_lightning() -> void:
	if lightning_tween != null and lightning_tween.is_valid():
		lightning_tween.kill()

	lightning_flash.modulate.a = 0.0
	lightning_tween = create_tween()
	lightning_tween.tween_property(lightning_flash, "modulate:a", 0.5, 0.04)
	lightning_tween.tween_property(lightning_flash, "modulate:a", 0.08, 0.08)
	lightning_tween.tween_property(lightning_flash, "modulate:a", 0.38, 0.04)
	lightning_tween.tween_property(lightning_flash, "modulate:a", 0.0, 0.22)


func schedule_powerup_spawn(first_spawn := false) -> void:
	powerup_spawn_timer.wait_time = (
		randf_range(15.0, 30.0)
		if first_spawn
		else randf_range(85.0, 95.0)
	)
	powerup_spawn_timer.start()


func _on_powerup_spawn_timer_timeout() -> void:
	if is_game_over:
		return

	if (
		not choosing_upgrade
		and powerup_carrier_scene != null
		and get_tree().get_nodes_in_group("powerup_carriers").is_empty()
	):
		var carrier := powerup_carrier_scene.instantiate() as Area2D
		carrier.destroyed.connect(_on_powerup_carrier_destroyed)
		add_child(carrier)
		var side := -1 if randf() < 0.5 else 1
		carrier.call("spawn_from_side", side, randf_range(125.0, 210.0))

	schedule_powerup_spawn()


func _on_powerup_carrier_destroyed(drop_position: Vector2) -> void:
	if powerup_item_scene == null or is_game_over:
		return

	var roll := randf()
	var selected_type := PowerupItem.PowerupType.BOMB

	if roll < 0.30:
		selected_type = PowerupItem.PowerupType.UNLIMITED_AMMO
	elif roll < 0.60:
		selected_type = PowerupItem.PowerupType.TRIPLE_SHOT
	elif roll < 0.85:
		selected_type = PowerupItem.PowerupType.INVULNERABLE

	var item := powerup_item_scene.instantiate() as PowerupItem
	item.collected.connect(_on_powerup_collected)
	add_child(item)
	item.global_position = drop_position
	item.setup(selected_type)


func _on_powerup_collected(powerup_type: int, player_node: Node) -> void:
	if is_game_over or not is_instance_valid(player_node):
		return

	powerup_pickup_sound.play()

	match powerup_type:
		PowerupItem.PowerupType.BOMB:
			show_powerup_message("SCREEN BOMB!", Color("ff9d32"))
			call_deferred("perform_screen_bomb")
		PowerupItem.PowerupType.UNLIMITED_AMMO:
			player_node.call("activate_unlimited_ammo", POWERUP_DURATION)
			show_powerup_message("UNLIMITED AMMO!", Color("43ddff"))
		PowerupItem.PowerupType.TRIPLE_SHOT:
			player_node.call("activate_triple_shot", POWERUP_DURATION)
			show_powerup_message("TRIPLE SHOT!", Color("ffb52e"))
		PowerupItem.PowerupType.INVULNERABLE:
			player_node.call(
				"activate_powerup_invulnerability",
				POWERUP_DURATION
			)
			invulnerability_sound.play()
			show_powerup_message("INVULNERABLE!", Color("73e8ff"))


func perform_screen_bomb() -> void:
	screen_bomb_sound.play()
	shake_camera(13.0, 0.45)

	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("destroy"):
			enemy.call("destroy", true)

	powerup_flash.color = Color(1.0, 0.72, 0.25, 0.9)
	powerup_flash.show()
	var flash_tween := create_tween()
	flash_tween.tween_property(powerup_flash, "color:a", 0.0, 0.35)
	flash_tween.tween_callback(powerup_flash.hide)


func update_powerup_status() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		powerup_status_label.hide()
		return

	var status_parts: Array[String] = []
	var unlimited_time := float(player.call("get_unlimited_ammo_time_left"))
	var triple_time := float(player.call("get_triple_shot_time_left"))
	var invulnerable_time := float(
		player.call("get_powerup_invulnerability_time_left")
	)

	if unlimited_time > 0.0:
		status_parts.append("INF AMMO %.1fs" % unlimited_time)
	if triple_time > 0.0:
		status_parts.append("TRIPLE SHOT %.1fs" % triple_time)
	if invulnerable_time > 0.0:
		status_parts.append("INVULNERABLE %.1fs" % invulnerable_time)

	if status_parts.is_empty():
		powerup_status_label.hide()
	else:
		powerup_status_label.text = "   |   ".join(status_parts)
		powerup_status_label.show()


func show_powerup_message(message: String, color: Color) -> void:
	if powerup_message_tween != null and powerup_message_tween.is_valid():
		powerup_message_tween.kill()

	powerup_message_label.text = message
	powerup_message_label.add_theme_color_override("font_color", color)
	powerup_message_label.modulate.a = 1.0
	powerup_message_label.show()
	powerup_message_tween = create_tween()
	powerup_message_tween.tween_interval(1.0)
	powerup_message_tween.tween_property(
		powerup_message_label,
		"modulate:a",
		0.0,
		0.35
	)
	powerup_message_tween.tween_callback(powerup_message_label.hide)


func _on_enemy_spawn_timer_timeout() -> void:
	if not wave_active:
		return

	if wave_spawned >= wave_target:
		enemy_spawn_timer.stop()
		return

	var current_enemies := get_tree().get_nodes_in_group(
		"enemies"
	).size()

	if current_enemies >= max_enemies:
		return

	var selected_enemy_scene := choose_enemy_scene()

	if selected_enemy_scene == null:
		push_error("An enemy scene is not assigned in Main.")
		return

	var enemy := selected_enemy_scene.instantiate() as Area2D

	if enemy.has_method("apply_difficulty"):
		enemy.call("apply_difficulty", difficulty_level)

	enemy.connect("destroyed", _on_enemy_destroyed)
	add_child(enemy)

	if enemy.has_method("spawn_from_side"):
		var side := -1 if randf() < 0.5 else 1
		show_side_warning(side)
		enemy.call("spawn_from_side", side)
	else:
		enemy.global_position = Vector2(
			randf_range(60.0, 1092.0),
			randf_range(80.0, 220.0)
		)

	wave_spawned += 1

	if wave_spawned >= wave_target:
		enemy_spawn_timer.stop()


func choose_enemy_scene() -> PackedScene:
	var ambush_probability := clampf(
		0.05 + (wave_number - ambush_start_wave) * 0.015,
		0.05,
		0.12
	)

	if (
		wave_number >= ambush_start_wave
		and ambush_enemy_scene != null
		and randf() < ambush_probability
	):
		return ambush_enemy_scene

	var kamikaze_probability := clampf(
		0.08 + (wave_number - kamikaze_start_wave) * 0.02,
		0.08,
		0.18
	)

	if (
		wave_number >= kamikaze_start_wave
		and kamikaze_enemy_scene != null
		and randf() < kamikaze_probability
	):
		return kamikaze_enemy_scene

	var ground_probability := clampf(
		0.2 + (wave_number - ground_enemy_start_wave) * 0.06,
		0.2,
		0.5
	)

	if (
		wave_number >= ground_enemy_start_wave
		and ground_enemy_scene != null
		and randf() < ground_probability
	):
		return ground_enemy_scene

	if (
		difficulty_level >= 3
		and fast_enemy_scene != null
		and randf() < 0.12
	):
		return fast_enemy_scene

	if (
		difficulty_level >= 2
		and aimed_enemy_scene != null
		and randf() < 0.35
	):
		return aimed_enemy_scene

	return enemy_scene


func show_side_warning(side: int) -> void:
	ground_warning_sound.play()
	var warning := Label.new()
	warning.text = ">>" if side < 0 else "<<"
	warning.position = Vector2(
		18.0 if side < 0 else 1090.0,
		500.0
	)
	warning.add_theme_color_override(
		"font_color",
		Color("ff365c")
	)
	warning.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	warning.add_theme_constant_override("outline_size", 5)
	warning.add_theme_font_size_override("font_size", 32)
	$HUD.add_child(warning)

	var tween := create_tween()

	for _blink in range(3):
		tween.tween_property(warning, "modulate:a", 0.15, 0.12)
		tween.tween_property(warning, "modulate:a", 1.0, 0.12)

	tween.tween_callback(warning.queue_free)


func start_wave() -> void:
	wave_active = true
	wave_spawned = 0
	wave_defeated = 0
	difficulty_level = wave_number - 1
	wave_target = (
		base_enemies_per_wave
		+ (wave_number - 1) * enemies_per_wave_growth
	)

	max_enemies = mini(
		initial_max_enemies + difficulty_level,
		final_max_enemies
	)

	enemy_spawn_timer.wait_time = maxf(
		2.0 - difficulty_level * 0.2,
		0.7
	)

	show_wave_message("WAVE %d" % wave_number)
	enemy_spawn_timer.start()
	update_wave_indicator()

	print(
		"Wave: ",
		wave_number,
		" | Enemies: ",
		wave_target
	)


func _on_enemy_destroyed(enemy_score: int) -> void:
	if is_game_over or not wave_active:
		return

	add_score(enemy_score)
	wave_defeated += 1

	if wave_defeated >= wave_target:
		finish_wave()


func spawn_kill_feedback(pos: Vector2, enemy_score: int) -> void:
	if is_game_over:
		return
	spawn_score_popup(pos, enemy_score)


func spawn_score_popup(pos: Vector2, amount: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override(
		"font_color",
		Color(1.0, 0.95, 0.55, 1.0)
	)
	popup.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 1.0)
	)
	popup.add_theme_constant_override("outline_size", 4)
	popup.position = pos + Vector2(-30.0, -40.0)
	popup.modulate.a = 0.0
	add_child(popup)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		popup,
		"position:y",
		popup.position.y - 34.0,
		0.9
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(popup, "modulate:a", 1.0, 0.15)
	tween.chain().tween_property(popup, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(popup.queue_free)


func finish_wave() -> void:
	wave_active = false
	enemy_spawn_timer.stop()

	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()

	show_wave_message("WAVE CLEARED")

	if wave_number % 5 == 0:
		grant_extra_life("5-WAVE LIFE BONUS!")

	show_upgrade_choices()


func show_upgrade_choices() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player) or is_game_over:
		return

	var available_upgrades: Array[String] = []

	for upgrade_id: String in UPGRADE_DEFINITIONS:
		if bool(player.call("can_apply_upgrade", upgrade_id)):
			available_upgrades.append(upgrade_id)

	current_upgrade_ids = choose_weighted_upgrades(available_upgrades, 3)

	if current_upgrade_ids.size() < 3:
		push_error("There are fewer than three available upgrades.")
		wave_break_timer.wait_time = wave_break_duration
		wave_break_timer.start()
		return

	choosing_upgrade = true
	wave_label.hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED

	for group_name in ["powerup_carriers", "powerup_items"]:
		for powerup in get_tree().get_nodes_in_group(group_name):
			powerup.process_mode = Node.PROCESS_MODE_DISABLED

	for index in range(upgrade_buttons.size()):
		var upgrade_data: Dictionary = UPGRADE_DEFINITIONS[
			current_upgrade_ids[index]
		]
		upgrade_buttons[index].text = "%d   %s\n\n%s" % [
			index + 1,
			str(upgrade_data["title"]),
			str(upgrade_data["description"]),
		]

	upgrade_overlay.show()
	upgrade_buttons[0].grab_focus()


func choose_weighted_upgrades(
	available_upgrades: Array[String], amount: int
) -> Array[String]:
	var remaining: Array[String] = available_upgrades.duplicate()
	var chosen: Array[String] = []

	while not remaining.is_empty() and chosen.size() < amount:
		var total_weight := 0.0

		for upgrade_id: String in remaining:
			total_weight += float(
				UPGRADE_DEFINITIONS[upgrade_id].get("selection_weight", 1.0)
			)

		var roll := randf() * total_weight
		var selected_index := remaining.size() - 1

		for index in range(remaining.size()):
			var upgrade_id: String = remaining[index]
			roll -= float(
				UPGRADE_DEFINITIONS[upgrade_id].get("selection_weight", 1.0)
			)

			if roll <= 0.0:
				selected_index = index
				break

		chosen.append(remaining[selected_index])
		remaining.remove_at(selected_index)

	return chosen


func _on_upgrade_button_pressed(index: int) -> void:
	if not choosing_upgrade or index >= current_upgrade_ids.size():
		return

	var player := get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		return

	var upgrade_id := current_upgrade_ids[index]
	var upgrade_data: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]

	if not bool(player.call("apply_upgrade", upgrade_id)):
		return

	choosing_upgrade = false
	upgrade_overlay.hide()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE

	for group_name in ["powerup_carriers", "powerup_items"]:
		for powerup in get_tree().get_nodes_in_group(group_name):
			powerup.process_mode = Node.PROCESS_MODE_PAUSABLE

	show_wave_message("UPGRADE: %s" % str(upgrade_data["title"]))
	wave_break_timer.wait_time = wave_break_duration
	wave_break_timer.start()


func _on_wave_break_timer_timeout() -> void:
	wave_number += 1
	start_wave()


func show_wave_message(message: String) -> void:
	wave_label.text = message
	wave_label.show()
	wave_message_timer.start()


func _on_wave_message_timer_timeout() -> void:
	wave_label.hide()


func shake_camera(strength: float, duration: float) -> void:
	camera_shake_strength = maxf(camera_shake_strength, strength)
	camera_shake_time = maxf(camera_shake_time, duration)


func update_camera_shake(delta: float) -> void:
	if camera_shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		return

	camera_shake_time -= delta
	camera.offset = Vector2(
		randf_range(-camera_shake_strength, camera_shake_strength),
		randf_range(-camera_shake_strength, camera_shake_strength)
	)
	camera_shake_strength = move_toward(
		camera_shake_strength,
		0.0,
		delta * 18.0
	)


func _on_player_health_changed(current_health: int) -> void:
	for index in range(heart_textures.size()):
		heart_textures[index].visible = index < current_health


func _on_player_ammo_changed(
	current_ammo: int,
	magazine_size: int
) -> void:
	if current_ammo < 0:
		ammo_label.text = "INF / INF"
		return

	ammo_label.text = "%02d / %02d" % [
		current_ammo,
		magazine_size
	]


func add_score(points: int) -> void:
	if points <= 0:
		return

	current_score += points
	update_score_label()

	while current_score >= next_extra_life_score:
		grant_extra_life()
		next_extra_life_score += EXTRA_LIFE_SCORE_INTERVAL


func grant_extra_life(message := "EXTRA LIFE!") -> void:
	var player := get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		return

	if bool(player.call("give_extra_life", MAX_PLAYER_HEALTH)):
		extra_life_sound.play()
		show_powerup_message(message, Color("ff4b4b"))


func update_score_label() -> void:
	score_label.text = "SCORE: %06d" % current_score


func update_wave_indicator() -> void:
	wave_indicator_label.text = "WAVE %d" % wave_number


func _on_player_died() -> void:
	is_game_over = true
	choosing_upgrade = false
	upgrade_overlay.hide()
	stop_gameplay()
	start_game_over_music()
	status_panel.hide()
	wave_indicator_label.hide()
	score_label.hide()
	wave_label.hide()
	powerup_status_label.hide()
	game_over_overlay.show()

	game_over_label.text = (
		"GAME OVER\n"
		+ "SCORE: %06d\n" % current_score
		+ "TIME: %.1f SECONDS" % elapsed_time
	)
	game_over_label.show()

	if score_qualifies(current_score):
		show_initials_input()
	else:
		show_leaderboard()


func stop_gameplay() -> void:
	enemy_spawn_timer.stop()
	wave_break_timer.stop()
	wave_message_timer.stop()
	powerup_spawn_timer.stop()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.call_deferred(
			"set_process_mode",
			Node.PROCESS_MODE_DISABLED
		)

	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.call_deferred(
			"set_process_mode",
			Node.PROCESS_MODE_DISABLED
		)

	for powerup_group in ["powerup_carriers", "powerup_items"]:
		for powerup in get_tree().get_nodes_in_group(powerup_group):
			powerup.call_deferred(
				"set_process_mode",
				Node.PROCESS_MODE_DISABLED
			)


func score_qualifies(score_value: int) -> bool:
	if leaderboard.size() < MAX_SCORES:
		return true

	var last_entry: Dictionary = leaderboard[MAX_SCORES - 1]
	var last_score := int(last_entry.get("score", 0))

	if score_value == last_score:
		return elapsed_time > float(last_entry.get("time", 0.0))

	return score_value > last_score


func show_initials_input() -> void:
	waiting_for_initials = true
	restart_label.hide()

	initials_prompt.show()
	initials_input.show()
	initials_input.clear()
	initials_input.grab_focus()

func toggle_pause() -> void:
	if is_game_over or choosing_upgrade:
		return

	get_tree().paused = not get_tree().paused
	gameplay_music.stream_paused = get_tree().paused

	if get_tree().paused:
		$HUD/PauseOverlay.show()
	else:
		$HUD/PauseOverlay.hide()


func _on_initials_input_text_submitted(new_text: String) -> void:
	if not waiting_for_initials:
		return

	var initials := new_text.strip_edges().to_upper()

	if initials.is_empty():
		initials_input.placeholder_text = "TYPE SOMETHING"
		return

	while initials.length() < 8:
		initials += "-"

	initials = initials.substr(0, 8)

	leaderboard.append({
		"initials": initials,
		"score": current_score,
		"time": elapsed_time
	})

	leaderboard.sort_custom(sort_scores)

	if leaderboard.size() > MAX_SCORES:
		leaderboard.resize(MAX_SCORES)

	save_leaderboard()
	LeaderboardClient.submit_score(initials, current_score, elapsed_time, wave_number)

	waiting_for_initials = false
	initials_input.release_focus()
	initials_input.hide()
	initials_prompt.hide()

	show_leaderboard()


func sort_scores(first_entry: Dictionary, second_entry: Dictionary) -> bool:
	var first_score := int(first_entry.get("score", 0))
	var second_score := int(second_entry.get("score", 0))

	if first_score == second_score:
		return (
			float(first_entry.get("time", 0.0))
			> float(second_entry.get("time", 0.0))
		)

	return first_score > second_score


func show_leaderboard() -> void:
	_leaderboard_online_ready = false
	var ranking_text := "HIGH SCORES\n\n"

	if leaderboard.is_empty():
		ranking_text += "NO SCORES YET\n"
	else:
		for index in range(leaderboard.size()):
			var entry: Dictionary = leaderboard[index]

			ranking_text += "%d. %s   %06d   %.1f s\n" % [
				index + 1,
				str(entry.get("initials", "---")),
				int(entry.get("score", 0)),
				float(entry.get("time", 0.0))
			]

	leaderboard_label.text = ranking_text
	leaderboard_label.show()
	restart_label.text = "PRESS R / START TO RESTART\nPRESS O / SELECT FOR MENU"
	restart_label.show()

	if LeaderboardClient.is_online_enabled():
		LeaderboardClient.request_top_scores(MAX_SCORES)


func on_online_leaderboard_response(ok: bool, body_text: String) -> void:
	if not ok:
		return
	if body_text.strip_edges().is_empty():
		return
	var parsed: Variant = JSON.parse_string(body_text)
	if parsed is not Array:
		return
	if parsed.is_empty():
		return
	var merged := leaderboard.duplicate()
	for entry in parsed:
		if not entry is Dictionary:
			continue
		merged.append({
			"initials": str(entry.get("player_name", "---")),
			"score": int(entry.get("score", 0)),
			"time": float(entry.get("survival_time", 0.0))
		})
	merged.sort_custom(sort_scores)
	var top := merged.slice(0, MAX_SCORES)
	var online_text := "GLOBAL TOP SCORES\n\n"
	for index in range(top.size()):
		var entry: Dictionary = top[index]
		online_text += "%d. %s   %06d   %.1f s\n" % [
			index + 1,
			str(entry.get("initials", "---")),
			int(entry.get("score", 0)),
			float(entry.get("time", 0.0))
		]
	leaderboard_label.text = online_text


func load_leaderboard() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(SCORE_PATH)

	if load_error != OK:
		return

	var loaded_entries = config.get_value(
		"leaderboard",
		"entries",
		[]
	)

	if loaded_entries is Array:
		leaderboard = loaded_entries

		for entry in leaderboard:
			if entry is Dictionary and not entry.has("score"):
				entry["score"] = int(
					round(float(entry.get("time", 0.0)) * 10.0)
				)

		leaderboard.sort_custom(sort_scores)


func save_leaderboard() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"leaderboard",
		"entries",
		leaderboard
	)

	var save_error := config.save(SCORE_PATH)

	if save_error != OK:
		push_error(
			"The high-score table could not be saved."
		)


func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if choosing_upgrade and event is InputEventJoypadButton and event.pressed:
		var button_index: int = event.button_index
		var focused := get_viewport().gui_get_focus_owner()
		var focused_index := upgrade_buttons.find(focused)

		if button_index == JOY_BUTTON_DPAD_LEFT:
			upgrade_buttons[maxi(0, focused_index - 1)].grab_focus()
			get_viewport().set_input_as_handled()
			return
		if button_index == JOY_BUTTON_DPAD_RIGHT:
			upgrade_buttons[mini(upgrade_buttons.size() - 1, focused_index + 1)].grab_focus()
			get_viewport().set_input_as_handled()
			return
		if button_index == JOY_BUTTON_A or button_index == JOY_BUTTON_X:
			if focused_index >= 0:
				_on_upgrade_button_pressed(focused_index)
				get_viewport().set_input_as_handled()
			return

	if (
		choosing_upgrade
		and event is InputEventKey
		and event.pressed
		and not event.echo
	):
		match event.physical_keycode:
			KEY_1:
				_on_upgrade_button_pressed(0)
			KEY_2:
				_on_upgrade_button_pressed(1)
			KEY_3:
				_on_upgrade_button_pressed(2)
		return

	if (
		is_game_over
		and not waiting_for_initials
		and event.is_action_pressed("restart")
	):
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
		return

	if (
		is_game_over
		and not waiting_for_initials
		and event.is_action_pressed("open_options")
	):
		get_tree().change_scene_to_file("res://scenes/intro.tscn")
