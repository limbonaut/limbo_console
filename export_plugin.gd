@tool
extends EditorExportPlugin
## Ensures configuration file is exported.

const ConsoleOptions := preload("res://addons/limbo_console/console_options.gd")


func _get_name() -> String:
	return "LimboConsoleExportPlugin"


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	var file := FileAccess.open(ConsoleOptions.CONFIG_PATH, FileAccess.READ)
	if file:
		add_file(ConsoleOptions.CONFIG_PATH, file.get_buffer(file.get_length()), false)
	else:
		printerr("LimboConsole: Config file not found - skipped.")
