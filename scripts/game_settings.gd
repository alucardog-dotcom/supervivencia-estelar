extends Node

signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

const SETTINGS_PATH := "user://settings.cfg"

var music_volume := 0.6
var sfx_volume := 0.8
var keybinds := {}  # action -> physical keycode (int)
var joypad_bindings := {}  # action -> joypad button index


func _ready() -> void:
	load_settings()


func music_db() -> float:
	return linear_to_db(maxf(music_volume, 0.0001))


func sfx_db() -> float:
	return linear_to_db(maxf(sfx_volume, 0.0001))


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	GameSettings.emit_signal("music_volume_changed", music_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	GameSettings.emit_signal("sfx_volume_changed", sfx_volume)
	save_settings()


func get_current_keycode(action: String) -> int:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return event.physical_keycode
	return 0


func get_current_joypad_button(action: String) -> int:
	if joypad_bindings.has(action):
		return int(joypad_bindings[action])
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return -1


func bind_action(action: String, keycode: int) -> void:
	if not InputMap.has_action(action) or keycode <= 0:
		return
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey:
			InputMap.action_erase_event(action, existing)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
	keybinds[action] = keycode
	save_settings()


func bind_joypad_action(action: String, button_index: int) -> void:
	if not InputMap.has_action(action) or button_index < 0:
		return
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton:
			InputMap.action_erase_event(action, existing)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)
	joypad_bindings[action] = button_index
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("options", "music_volume", music_volume)
	config.set_value("options", "sfx_volume", sfx_volume)
	if not keybinds.is_empty():
		config.set_value("controls", "keybinds", keybinds)
	if not joypad_bindings.is_empty():
		config.set_value("controls", "joypad_bindings", joypad_bindings)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = config.get_value("options", "music_volume", 0.6)
	sfx_volume = config.get_value("options", "sfx_volume", 0.8)
	var saved: Variant = config.get_value("controls", "keybinds", {})
	if saved is Dictionary:
		keybinds = saved
		_restore_keybinds()
	joypad_bindings = config.get_value("controls", "joypad_bindings", {})
	if joypad_bindings is Dictionary:
		_restore_joypad_bindings()


func _restore_keybinds() -> void:
	for action: String in keybinds:
		if not InputMap.has_action(action):
			continue
		var keycode: int = keybinds[action]
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey:
				InputMap.action_erase_event(action, existing)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func _restore_joypad_bindings() -> void:
	for action: String in joypad_bindings:
		if not InputMap.has_action(action):
			continue
		var button_index: int = joypad_bindings[action]
		for existing in InputMap.action_get_events(action):
			if existing is InputEventJoypadButton:
				InputMap.action_erase_event(action, existing)
		var ev := InputEventJoypadButton.new()
		ev.button_index = button_index
		InputMap.action_add_event(action, ev)


func describe_key(action: String) -> String:
	var keycode := get_current_keycode(action)
	return "?" if keycode == 0 else OS.get_keycode_string(keycode)


func describe_joypad(action: String) -> String:
	var button_index := get_current_joypad_button(action)
	var names := {
		0: "A", 1: "B", 2: "X", 3: "Y", 4: "SELECT",
		5: "RB", 6: "START", 7: "L3", 8: "R3",
		9: "LB", 10: "BACK", 11: "DPAD UP", 12: "DPAD DOWN",
		13: "DPAD LEFT", 14: "DPAD RIGHT",
	}
	return "?" if button_index < 0 else str(names.get(button_index, "BUTTON %d" % button_index))
