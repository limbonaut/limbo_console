@tool
extends EditorPlugin

const ConsoleOptions := preload("res://addons/limbo_console/console_options.gd")
const ConfigMapper := preload("res://addons/limbo_console/config_mapper.gd")

func _enter_tree() -> void:
	add_autoload_singleton("LimboConsole", "res://addons/limbo_console/limbo_console.gd")

	# Sync config file (create if not exists)
	var console_options := ConsoleOptions.new()
	var do_project_setting_save: bool = false
	ConfigMapper.load_from_config(console_options)
	ConfigMapper.save_to_config(console_options)

	if not ProjectSettings.has_setting("input/limbo_console_toggle"):
		print("LimboConsole: Adding \"limbo_console_toggle\" input action to project settings...")

		var key_event := InputEventKey.new()
		key_event.keycode = KEY_QUOTELEFT

		ProjectSettings.set_setting("input/limbo_console_toggle", {
			"deadzone": 0.5,
			"events": [key_event],
		})
		do_project_setting_save = true
		
	if not ProjectSettings.has_setting("input/limbo_auto_complete_reverse"):
		print("LimboConsole: Adding \"limbo_auto_complete_reverse\" input action to project settings...")
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_TAB
		key_event.shift_pressed = true
		
		ProjectSettings.set_setting("input/limbo_auto_complete_reverse", {
			"deadzone": 0.5,
			"events": [key_event],
		})
		do_project_setting_save = true
	
	if not ProjectSettings.has_setting("input/limbo_console_search_history"):
		print("LimboConsole: Adding \"limbo_console_search_history\" input action to project settings...")
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_R
		key_event.ctrl_pressed = true
		
		ProjectSettings.set_setting("input/limbo_console_search_history", {
			"deadzone": 0.5,
			"events": [key_event],
		})
		do_project_setting_save = true
		
	if do_project_setting_save:
		ProjectSettings.save()


func _exit_tree() -> void:
	remove_autoload_singleton("LimboConsole")
