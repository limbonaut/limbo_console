extends RefCounted

# Configuration is outside of limbo_console directory for compatibility with GIT submodules
const CONFIG_PATH := "res://addons/limbo_console.cfg"

@export var aliases := {
	"usage": "help",
	"exit": "quit",
}
@export var disable_in_release_build: bool = false
@export var print_to_stdout: bool = false

@export_category("appearance")
@export var custom_theme: String = "res://addons/limbo_console_theme.tres"
@export var height_ratio: float = 0.5
@export var opacity: float = 1.0
@export var sparse_mode: bool = false # Print empty line after each command execution.

@export_category("greet")
@export var greet_user: bool = true
@export var greeting_message: String = "{project_name}"
@export var greet_using_ascii_art: bool = true

@export_category("history")
@export var persist_history: bool = true
@export var history_lines: int = 1000
