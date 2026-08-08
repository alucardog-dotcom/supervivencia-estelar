extends Control

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var title_logo: Sprite2D = $TitleLogo
@onready var subtitle_label: Label = $SubtitleLabel
@onready var prompt_label: Label = $PromptLabel
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var music: AudioStreamPlayer = $Music

var can_start := false
var is_leaving := false


func _ready() -> void:
	title_logo.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	prompt_label.modulate.a = 0.0
	fade_overlay.modulate.a = 1.0
	music.volume_db = GameSettings.music_db()
	music.play()
	play_title_reveal()


func play_title_reveal() -> void:
	var reveal := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	reveal.set_parallel(true)
	reveal.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)
	reveal.tween_property(title_logo, "modulate:a", 1.0, 0.65)
	reveal.tween_property(
		title_logo,
		"scale",
		Vector2.ONE,
		0.65
	).from(Vector2(1.12, 1.12))
	reveal.tween_property(
		subtitle_label,
		"modulate:a",
		1.0,
		0.65
	).set_delay(0.25)
	await reveal.finished

	prompt_label.modulate.a = 1.0
	can_start = true

	var prompt_pulse := create_tween().set_loops()
	prompt_pulse.tween_property(prompt_label, "modulate:a", 0.28, 0.65)
	prompt_pulse.tween_property(prompt_label, "modulate:a", 1.0, 0.65)


func _unhandled_input(event: InputEvent) -> void:
	if not can_start or is_leaving:
		return

	var is_key := event is InputEventKey
	var is_joy := event is InputEventJoypadButton
	var is_mouse := event is InputEventMouseButton

	if is_key and (event.pressed and not event.echo):
		if event.physical_keycode == KEY_O:
			open_options()
			return
	if (
		is_joy
		and event.pressed
		and event.button_index == JOY_BUTTON_BACK
	):
		open_options()
		return

	var pressed := false
	if is_key:
		pressed = event.pressed and not event.echo
	elif is_joy:
		pressed = event.pressed
	elif is_mouse:
		pressed = event.pressed

	if pressed:
		go_to_game()


func open_options() -> void:
	is_leaving = true
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")


func go_to_game() -> void:
	is_leaving = true
	var exit_fade := create_tween()
	exit_fade.set_parallel(true)
	exit_fade.tween_property(fade_overlay, "modulate:a", 1.0, 0.3)
	exit_fade.tween_property(music, "volume_db", -35.0, 0.3)
	await exit_fade.finished
	get_tree().change_scene_to_file(MAIN_SCENE)
