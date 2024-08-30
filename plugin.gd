@tool
extends EditorPlugin

const ConsoleOptions := preload("res://addons/limbo_console/console_options.gd")
const ConfigMapper := preload("res://addons/limbo_console/config_mapper.gd")

func _enter_tree() -> void:
	add_autoload_singleton("LimboConsole", "res://addons/limbo_console/limbo_console.gd")

	# Sync config file (create if not exists)
	var console_options := ConsoleOptions.new()
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
		ProjectSettings.save()


func _exit_tree() -> void:
	remove_autoload_singleton("LimboConsole")
