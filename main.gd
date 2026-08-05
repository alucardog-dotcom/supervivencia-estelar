extends Node2D

const SCORE_PATH := "user://arcade_scores.cfg"
const MAX_SCORES := 5

@export var enemy_scene: PackedScene
@export var aimed_enemy_scene: PackedScene
@export var fast_enemy_scene: PackedScene
@export var initial_max_enemies: int = 3
@export var final_max_enemies: int = 8

@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var difficulty_timer: Timer = $DifficultyTimer
@onready var health_label: Label = $HUD/HealthLabel
@onready var time_label: Label = $HUD/TimeLabel
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


func _ready() -> void:
	game_over_label.hide()
	initials_prompt.hide()
	initials_input.hide()
	leaderboard_label.hide()
	game_over_overlay.hide()

	max_enemies = initial_max_enemies
	load_leaderboard()

	if not enemy_spawn_timer.timeout.is_connected(
		_on_enemy_spawn_timer_timeout
	):
		enemy_spawn_timer.timeout.connect(
			_on_enemy_spawn_timer_timeout
		)

	if not difficulty_timer.timeout.is_connected(
		_on_difficulty_timer_timeout
	):
		difficulty_timer.timeout.connect(
			_on_difficulty_timer_timeout
		)

	if not initials_input.text_submitted.is_connected(
		_on_initials_input_text_submitted
	):
		initials_input.text_submitted.connect(
			_on_initials_input_text_submitted
		)

	enemy_spawn_timer.start()
	difficulty_timer.start()


func _process(delta: float) -> void:
	if is_game_over:
		return

	elapsed_time += delta
	time_label.text = "TIEMPO: %.1f" % elapsed_time


func _on_enemy_spawn_timer_timeout() -> void:
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
	add_child(enemy)

	enemy.global_position = Vector2(
		randf_range(60.0, 1092.0),
		randf_range(80.0, 220.0)
	)


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


func _on_difficulty_timer_timeout() -> void:
	difficulty_level += 1

	max_enemies = mini(
		initial_max_enemies + difficulty_level,
		final_max_enemies
	)

	enemy_spawn_timer.wait_time = maxf(
		2.0 - difficulty_level * 0.2,
		0.7
	)

	print(
		"Nivel de dificultad: ",
		difficulty_level,
		" | Máximo de enemigos: ",
		max_enemies
	)


func _on_player_health_changed(current_health: int) -> void:
	var hearts := ""

	for _heart in range(current_health):
		hearts += "♥ "

	health_label.text = "VIDA: " + hearts


func _on_player_died() -> void:
	is_game_over = true
	stop_gameplay()
	health_label.hide()
	time_label.hide()
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
	difficulty_timer.stop()

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
