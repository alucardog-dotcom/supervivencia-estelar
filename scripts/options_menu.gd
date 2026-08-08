extends Control

const INTRO_SCENE := "res://scenes/intro.tscn"

const BINDABLE_ACTIONS := [
	["move_left", "MOVE LEFT"],
	["move_right", "MOVE RIGHT"],
	["aim_up", "AIM UP"],
	["crouch", "CROUCH"],
	["jump", "JUMP"],
	["shoot", "SHOOT"],
	["reload", "RELOAD"],
	["pause", "PAUSE"],
	["open_options", "OPTIONS MENU"],
	["restart", "RESTART"],
]

@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var bindings_list: VBoxContainer = %BindingsList

var capturing_action: String = ""
var capturing_button: Button = null
var capturing_kind: String = ""


func _ready() -> void:
	music_slider.value = GameSettings.music_volume
	sfx_slider.value = GameSettings.sfx_volume
	_update_volume_labels()
	_build_bindings()


func _build_bindings() -> void:
	for child in bindings_list.get_children():
		child.queue_free()
	for pair: Array in BINDABLE_ACTIONS:
		var action: String = pair[0]
		var label_text: String = pair[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var label := Label.new()
		label.custom_minimum_size = Vector2(150, 0)
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)

		for kind in ["KEY", "PAD"]:
			var bind_button := Button.new()
			bind_button.custom_minimum_size = Vector2(105, 32)
			bind_button.text = _describe_binding(action, kind)
			bind_button.pressed.connect(
				_on_bind_pressed.bind(action, bind_button, kind)
			)
			row.add_child(bind_button)

		bindings_list.add_child(row)


func _on_bind_pressed(action: String, button: Button, kind: String) -> void:
	if capture_is_busy():
		return
	capturing_action = action
	capturing_button = button
	capturing_kind = kind
	button.text = "PRESS %s..." % kind
	button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if capturing_action.is_empty():
		if event.is_action_pressed("ui_cancel"):
			go_back()
		return
	if event is InputEventKey and event.pressed and event.echo:
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_cancel_capture()
		get_viewport().set_input_as_handled()
		return
	if capturing_kind == "KEY" and event is InputEventKey and event.pressed:
		GameSettings.bind_action(capturing_action, event.physical_keycode)
	elif capturing_kind == "PAD" and event is InputEventJoypadButton and event.pressed:
		GameSettings.bind_joypad_action(capturing_action, event.button_index)
	else:
		return
	_finish_capture()
	get_viewport().set_input_as_handled()


func _describe_key(action: String) -> String:
	return GameSettings.describe_key(action)


func _describe_binding(action: String, kind: String) -> String:
	return GameSettings.describe_key(action) if kind == "KEY" else GameSettings.describe_joypad(action)


func _cancel_capture() -> void:
	if capturing_button != null:
		capturing_button.text = _describe_binding(capturing_action, capturing_kind)
	capturing_action = ""
	capturing_button = null
	capturing_kind = ""


func _finish_capture() -> void:
	if capturing_button != null:
		capturing_button.text = _describe_binding(capturing_action, capturing_kind)
	capturing_action = ""
	capturing_button = null
	capturing_kind = ""


func capture_is_busy() -> bool:
	return capturing_action != ""


func _update_volume_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)


func _on_music_volume_changed(value: float) -> void:
	music_value.text = "%d%%" % roundi(value * 100.0)
	GameSettings.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	sfx_value.text = "%d%%" % roundi(value * 100.0)
	GameSettings.set_sfx_volume(value)


func _on_back_pressed() -> void:
	go_back()


func go_back() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)
