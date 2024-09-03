extends RefCounted

# Configuration is outside of limbo_console directory for compatibility with GIT submodules
const CONFIG_PATH := "res://addons/limbo_console.cfg"

@export var custom_theme: String = "res://addons/limbo_console_theme.tres"
@export var print_to_godot_console: bool = true

@export_category("greet")
@export var greet_user: bool = true
@export var greeting_message: String = "{project_name}"
@export var greet_using_ascii_art: bool = true

@export_category("history")
@export var persist_history: bool = true
@export var history_lines: int = 1000
