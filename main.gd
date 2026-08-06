extends Node2D

const SCORE_PATH := "user://arcade_scores.cfg"
const MAX_SCORES := 5

@export var enemy_scene: PackedScene
@export var aimed_enemy_scene: PackedScene
@export var fast_enemy_scene: PackedScene
@export var initial_max_enemies: int = 3
@export var final_max_enemies: int = 8
@export var base_enemies_per_wave: int = 6
@export var enemies_per_wave_growth: int = 2
@export var wave_break_duration: float = 4.0

@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var wave_break_timer: Timer = $WaveBreakTimer
@onready var wave_message_timer: Timer = $WaveMessageTimer
@onready var camera: Camera2D = $Camera2D
@onready var status_panel: Panel = $HUD/StatusPanel
@onready var health_label: Label = $HUD/StatusPanel/HealthLabel
@onready var ammo_label: Label = $HUD/StatusPanel/AmmoLabel
@onready var time_label: Label = $HUD/TimeLabel
@onready var wave_label: Label = $HUD/WaveLabel
@onready var game_over_label: Label = $HUD/GameOverLabel
@onready var initials_prompt: Label = $HUD/InitialsPrompt
@onready var initials_input: LineEdit = $HUD/InitialsInput
@onready var leaderboard_label: Label = $HUD/LeaderboardLabel
@onready var game_over_overlay: ColorRect = $HUD/GameOverOverlay

var elapsed_time := 0.0
var difficulty_level := 0
var max_enemies: int
var is_game_over := false
var waiting_for_initials := false
var leaderboard: Array = []
var wave_number := 1
var wave_target := 0
var wave_spawned := 0
var wave_defeated := 0
var wave_active := false
var camera_shake_time := 0.0
var camera_shake_strength := 0.0


func _ready() -> void:
	game_over_label.hide()
	initials_prompt.hide()
	initials_input.hide()
	leaderboard_label.hide()
	game_over_overlay.hide()
	wave_label.hide()
	_on_player_health_changed(int($Player.get("health")))
	_on_player_ammo_changed(
		int($Player.get("current_ammo")),
		int($Player.get("magazine_size"))
	)

	max_enemies = initial_max_enemies
	load_leaderboard()

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

	if not initials_input.text_submitted.is_connected(
		_on_initials_input_text_submitted
	):
		initials_input.text_submitted.connect(
			_on_initials_input_text_submitted
		)

	start_wave()


func _process(delta: float) -> void:
	update_camera_shake(delta)

	if is_game_over:
		return

	elapsed_time += delta
	time_label.text = "TIEMPO: %.1f" % elapsed_time


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
		push_error("Falta asignar una escena enemiga en Main.")
		return

	var enemy := selected_enemy_scene.instantiate() as Area2D

	enemy.call("apply_difficulty", difficulty_level)
	enemy.connect("destroyed", _on_enemy_destroyed)
	add_child(enemy)

	enemy.global_position = Vector2(
		randf_range(60.0, 1092.0),
		randf_range(80.0, 220.0)
	)

	wave_spawned += 1

	if wave_spawned >= wave_target:
		enemy_spawn_timer.stop()


func choose_enemy_scene() -> PackedScene:
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

	show_wave_message("OLEADA %d" % wave_number)
	enemy_spawn_timer.start()

	print(
		"Oleada: ",
		wave_number,
		" | Enemigos: ",
		wave_target
	)


func _on_enemy_destroyed() -> void:
	if is_game_over or not wave_active:
		return

	wave_defeated += 1

	if wave_defeated >= wave_target:
		finish_wave()


func finish_wave() -> void:
	wave_active = false
	enemy_spawn_timer.stop()
	show_wave_message("OLEADA COMPLETADA")
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
	var hearts := ""

	for _heart in range(current_health):
		hearts += "♥ "

	health_label.text = hearts.strip_edges()


func _on_player_ammo_changed(
	current_ammo: int,
	magazine_size: int
) -> void:
	ammo_label.text = "%02d / %02d" % [
		current_ammo,
		magazine_size
	]


func _on_player_died() -> void:
	is_game_over = true
	stop_gameplay()
	status_panel.hide()
	time_label.hide()
	wave_label.hide()
	game_over_overlay.show()

	game_over_label.text = (
		"GAME OVER\n"
		+ "Tiempo: %.1f segundos" % elapsed_time
	)
	game_over_label.show()

	if score_qualifies(elapsed_time):
		show_initials_input()
	else:
		show_leaderboard()


func stop_gameplay() -> void:
	enemy_spawn_timer.stop()
	wave_break_timer.stop()
	wave_message_timer.stop()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.process_mode = Node.PROCESS_MODE_DISABLED


func score_qualifies(score: float) -> bool:
	if leaderboard.size() < MAX_SCORES:
		return true

	var last_entry: Dictionary = leaderboard[MAX_SCORES - 1]
	var last_score := float(last_entry.get("time", 0.0))

	return score > last_score


func show_initials_input() -> void:
	waiting_for_initials = true

	initials_prompt.show()
	initials_input.show()
	initials_input.clear()
	initials_input.grab_focus()


func _on_initials_input_text_submitted(new_text: String) -> void:
	if not waiting_for_initials:
		return

	var initials := new_text.strip_edges().to_upper()

	if initials.is_empty():
		initials_input.placeholder_text = "ESCRIBE ALGO"
		return

	while initials.length() < 3:
		initials += "-"

	initials = initials.substr(0, 3)

	leaderboard.append({
		"initials": initials,
		"time": elapsed_time
	})

	leaderboard.sort_custom(sort_scores)

	if leaderboard.size() > MAX_SCORES:
		leaderboard.resize(MAX_SCORES)

	save_leaderboard()

	waiting_for_initials = false
	initials_input.release_focus()
	initials_input.hide()
	initials_prompt.hide()

	show_leaderboard()


func sort_scores(first_entry: Dictionary, second_entry: Dictionary) -> bool:
	return (
		float(first_entry.get("time", 0.0))
		> float(second_entry.get("time", 0.0))
	)


func show_leaderboard() -> void:
	var ranking_text := "CLASIFICACIÓN\n\n"

	if leaderboard.is_empty():
		ranking_text += "SIN PUNTUACIONES\n"
	else:
		for index in range(leaderboard.size()):
			var entry: Dictionary = leaderboard[index]

			ranking_text += "%d. %s    %.1f s\n" % [
				index + 1,
				str(entry.get("initials", "---")),
				float(entry.get("time", 0.0))
			]

	leaderboard_label.text = ranking_text
	leaderboard_label.show()

	game_over_label.text += "\nPulsa R para reiniciar"


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
			"No se pudo guardar la clasificación."
		)


func _unhandled_input(event: InputEvent) -> void:
	if (
		is_game_over
		and not waiting_for_initials
		and event.is_action_pressed("restart")
	):
		get_tree().reload_current_scene()
