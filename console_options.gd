extends RefCounted

# The file is outside of limbo_console directory for compatibility with GIT submodules
const CONFIG_PATH := "res://addons/limbo_console.cfg"

@export var custom_theme: String = "res://addons/limbo_console_theme.tres"

@export_category("history")
@export var persist_history: bool = true
@export var history_lines: int = 1000
