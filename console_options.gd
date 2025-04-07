extends RefCounted

# Configuration is outside of limbo_console directory for compatibility with GIT submodules
const CONFIG_PATH := "res://addons/limbo_console.cfg"

@export var aliases := {
	"exit": "quit",
	"source": "exec",
	"usage": "help",
}
@export var disable_in_release_build: bool = false
@export var print_to_stdout: bool = false
@export var pause_when_open: bool = true

@export var commands_disabled_in_release: Array = [
	"eval" # enables arbitrary code execution and asset extraction in the running game.
]

@export_category("appearance")
@export var custom_theme: String = "res://addons/limbo_console_theme.tres"
@export var height_ratio: float = 0.5
@export var open_speed: float = 5.0 # For instant, set to a really high float like 99999.0
@export var opacity: float = 1.0
@export var sparse_mode: bool = false # Print empty line after each command execution.

@export_category("greet")
@export var greet_user: bool = true
@export var greeting_message: String = "{project_name}"
@export var greet_using_ascii_art: bool = true

@export_category("history")
@export var persist_history: bool = true
@export var history_lines: int = 1000

@export_category("autocomplete")
@export var autocomplete_use_history_with_matches: bool = true

@export_category("autoexec")
@export var autoexec_script: String = "user://autoexec.lcs"
@export var autoexec_auto_create: bool = true
