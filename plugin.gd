@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("LimboConsole", "res://addons/limbo_console/limbo_console.gd")

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
