@tool
extends EditorPlugin

const ConsoleOptions := preload("res://addons/limbo_console/console_options.gd")
const ConfigMapper := preload("res://addons/limbo_console/config_mapper.gd")

func _add_input_action(name : String, keycode : Key, shift := false, ctrl := false) -> int:
	if not ProjectSettings.has_setting("input/" + name):
		print("LimboConsole: Adding \"" + name + "\" input action to project settings...")

		var key_event := InputEventKey.new()
		key_event.keycode = keycode
		key_event.shift_pressed = shift
		key_event.ctrl_pressed = ctrl

		ProjectSettings.set_setting("input/" + name, {
			"deadzone": 0.5,
			"events": [key_event],
		})
		return 1
	return 0

func _enable_plugin() -> void:
	add_autoload_singleton("LimboConsole", "res://addons/limbo_console/limbo_console.gd")

	# Sync config file (create if not exists)
	var console_options := ConsoleOptions.new()
	ConfigMapper.load_from_config(console_options)
	ConfigMapper.save_to_config(console_options)

	var created_actions: int = 0
	created_actions += _add_input_action("limbo_console_toggle", KEY_QUOTELEFT)
	created_actions += _add_input_action("limbo_auto_complete_forward", KEY_TAB, false, false)
	created_actions += _add_input_action("limbo_auto_complete_reverse", KEY_TAB, true, false)
	created_actions += _add_input_action("limbo_auto_complete_with_list", KEY_TAB, false, true)
	created_actions += _add_input_action("limbo_console_search_history", KEY_R)

	if created_actions > 0:
		ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton("LimboConsole")
