extends CanvasLayer
## LimboConsole

signal toggled(is_shown)

const THEME_DEFAULT := "res://addons/limbo_console/res/default_theme.tres"
const HISTORY_FILE := "user://limbo_console_history.log"

const ConsoleOptions := preload("res://addons/limbo_console/console_options.gd")

var _options: ConsoleOptions

var _console_control: Control
var _content: RichTextLabel
var _command_line: LineEdit

var _color_command: Color
var _color_command_line: Color
var _color_command_mention: Color
var _color_error: Color
var _color_warning: Color
var _color_text: Color
var _color_debug: Color

var _commands: Dictionary
var _command_aliases: Dictionary
var _command_descriptions: Dictionary
var _history: PackedStringArray
var _hist_idx: int = -1
var _autocomplete_matches: PackedStringArray


func _init() -> void:
	layer = 9999
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

	_options = ConsoleOptions.new()

	_build_gui()
	_init_theme()
	_console_control.hide()

	if _options.persist_history:
		_load_history()

	_command_line.text_submitted.connect(_on_command_line_submitted)
	_command_line.text_changed.connect(_on_command_line_changed)

	info("[b]" + ProjectSettings.get_setting("application/config/name") + " console[/b]")
	_cmd_help()
	info(_format_tip("-----"))

	register_command(_cmd_aliases, "aliases", "list all aliases")
	register_command(clear_console, "clear", "clear console screen")
	register_command(_cmd_commands, "commands", "list all commands")
	register_command(info, "echo", "display a line of text")
	register_command(_cmd_help, "help", "show command info")
	register_command(_cmd_fps_max, "fps_max", "limit framerate")
	register_command(_cmd_fullscreen, "fullscreen", "toggle fullscreen mode")
	register_command(_cmd_quit, "quit", "exit the application")
	register_command(_cmd_vsync, "vsync", "adjust V-Sync")

	add_alias("usage", "help")
	add_alias("exit", "quit")


func _exit_tree() -> void:
	if _options.persist_history:
		_save_history()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("limbo_console_toggle"):
		toggle_console()
		get_viewport().set_input_as_handled()
	elif _console_control.visible and event is InputEventKey and event.is_pressed():
		var handled := true
		if event.keycode == KEY_UP:
			_hist_idx += 1
			_fill_from_history()
		elif event.keycode == KEY_DOWN:
			_hist_idx -= 1
			_fill_from_history()
		elif event.keycode == KEY_TAB:
			_autocomplete()
		elif event.keycode == KEY_PAGEUP:
			var scroll_bar: VScrollBar = _content.get_v_scroll_bar()
			scroll_bar.value -= scroll_bar.page
		elif event.keycode == KEY_PAGEDOWN:
			var scroll_bar: VScrollBar = _content.get_v_scroll_bar()
			scroll_bar.value += scroll_bar.page
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()


func _build_gui() -> void:
	var panel := PanelContainer.new()
	_console_control = panel
	panel.anchor_bottom = 0.5
	panel.anchor_right = 1.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	_content = RichTextLabel.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.scroll_active = true
	_content.scroll_following = true
	_content.bbcode_enabled = true
	# _content.selection_enabled = true
	# _content.context_menu_enabled = true
	_content.focus_mode = Control.FOCUS_CLICK
	vbox.add_child(_content)

	_command_line = LineEdit.new()
	vbox.add_child(_command_line)


func _init_theme() -> void:
	var theme: Theme
	if ResourceLoader.exists(_options.custom_theme, "Theme"):
		theme = load(_options.custom_theme)
	else:
		theme = load(THEME_DEFAULT)
	_console_control.theme = theme

	const CONSOLE_COLORS_THEME_TYPE := &"ConsoleColors"
	_color_command = theme.get_color(&"command_color", CONSOLE_COLORS_THEME_TYPE)
	_color_command_line = theme.get_color(&"command_line_color", CONSOLE_COLORS_THEME_TYPE)
	_color_command_mention = theme.get_color(&"command_mention_color", CONSOLE_COLORS_THEME_TYPE)
	_color_text = theme.get_color(&"text_color", CONSOLE_COLORS_THEME_TYPE)
	_color_error = theme.get_color(&"error_color", CONSOLE_COLORS_THEME_TYPE)
	_color_warning = theme.get_color(&"warning_color", CONSOLE_COLORS_THEME_TYPE)
	_color_debug = theme.get_color(&"debug_color", CONSOLE_COLORS_THEME_TYPE)

	_content.add_theme_color_override(&"default_color", _color_text)
	_command_line.add_theme_color_override(&"font_color", _color_command_line)


func _load_history() -> void:
	var file := FileAccess.open(HISTORY_FILE, FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			_history.append(line)
	file.close()


func _save_history() -> void:
	# Trim history first
	var max_lines: int = maxi(_options.history_lines, 0)
	if _history.size() > max_lines:
		_history = _history.slice(_history.size() - max_lines)

	var file := FileAccess.open(HISTORY_FILE, FileAccess.WRITE)
	if not file:
		push_error("LimboConsole: Failed to save console history to file: ", HISTORY_FILE)
		return
	for line in _history:
		file.store_line(line)
	file.close()


func show_console() -> void:
	if not _console_control.visible:
		_console_control.show()
		get_tree().paused = true
		_command_line.grab_focus()
		toggled.emit(true)


func hide_console() -> void:
	if _console_control.visible:
		_console_control.hide()
		get_tree().paused = false
		toggled.emit(false)


func toggle_console() -> void:
	if _console_control.visible:
		hide_console()
	else:
		show_console()


## Clears all messages in the console.
func clear_console() -> void:
	_content.text = ""


## Prints an info message to the console and the output.
func info(p_line: String) -> void:
	_print_line(p_line)


## Prints an error message to the console and the output.
func error(p_line: String) -> void:
	_print_line("[color=%s]ERROR:[/color] %s" % [_color_error.to_html(), p_line])


## Prints a warning message to the console and the output.
func warn(p_line: String) -> void:
	_print_line("[color=%s]WARNING:[/color] %s" % [_color_warning.to_html(), p_line])


## Prints a debug message to the console and the output.
func debug(p_line: String) -> void:
	_print_line("[color=%s]DEBUG: %s[/color]" % [_color_debug.to_html(), p_line])


func _print_line(p_line: String) -> void:
	var line: String = p_line + "\n"
	_content.text += line
	print_rich(line.strip_edges())


## Registers a new command for the specified callable. [br]
## Optionally, you can provide a name and a description.
func register_command(p_func: Callable, p_name: String = "", p_desc: String = "") -> void:
	if not _validate_callable(p_func):
		error("Failed to register command: %s" % [p_func if p_name.is_empty() else p_name])
		return
	var name: String = p_name
	if name.is_empty():
		name = p_func.get_method().trim_prefix("_cmd").trim_prefix("_")
	if _commands.has(name):
		error("Command already registered: " + p_name)
		return
	if _command_aliases.has(name):
		warn("Command alias exists with the same name: " + p_name)
	_commands[name] = p_func
	_command_descriptions[name] = p_desc


## Unregisters the command specified by its name or a callable.
func unregister_command(p_func_or_name) -> void:
	var cmd_name: String
	if p_func_or_name is Callable:
		var key = _commands.find_key(p_func_or_name)
		if key != null:
			cmd_name = key
	elif p_func_or_name is String:
		cmd_name = p_func_or_name
	if cmd_name.is_empty() or not _commands.has(cmd_name):
		error("Unregister failed - command not found: " % [p_func_or_name])
		return
	_commands.erase(cmd_name)
	_command_descriptions.erase(cmd_name)


## Is a command or an alias registered by the given name.
func is_command_registered(p_name: String) -> bool:
	return _commands.has(p_name) or _command_aliases.has(p_name)


## Adds an alias for an existing command.
func add_alias(p_alias: String, p_existing: String) -> void:
	if is_command_registered(p_alias):
		error("Command or alias already registered: " + p_alias)
		return
	if not is_command_registered(p_existing):
		error("Command not found: " + p_existing)
		return
	_command_aliases[p_alias] = p_existing


## Removes an alias by name.
func remove_alias(p_name: String) -> void:
	_command_aliases.erase(p_name)


## Parses the command line and executes the command if it's valid.
func execute_command(p_command_line: String, p_silent: bool = false) -> void:
	p_command_line = p_command_line.strip_edges()
	if p_command_line.is_empty():
		return

	var argv: PackedStringArray = _parse_command_line(p_command_line)
	var command_name: String = argv[0]
	var command_args: Array = []

	var history_line: String = " ".join(argv)
	_push_history(history_line)
	if not p_silent:
		info("[color=%s][b]>[/b] %s[/color] %s" %
				[_color_command.to_html(), command_name, " ".join(argv.slice(1, argv.size()))])

	if not is_command_registered(command_name):
		error("Unknown command: " + command_name)
		_suggest_similar(argv, 0)
		return

	var dealiased_name: String = _command_aliases.get(command_name, command_name)

	var cmd: Callable = _commands.get(dealiased_name)
	var valid: bool = _parse_argv(argv, cmd, command_args)
	if valid:
		cmd.callv(command_args)
	else:
		_usage(command_name)


## Splits the command line string into an array of arguments (aka argv).
func _parse_command_line(p_line: String) -> PackedStringArray:
	var argv: PackedStringArray = []
	var arg: String = ""
	var in_quotes: bool = false
	var line: String = p_line.strip_edges()
	var start: int = 0
	var cur: int = 0
	for char in line:
		if char == '"':
			in_quotes = not in_quotes
		elif char == ' ' and not in_quotes:
			if cur > start:
				argv.append(line.substr(start, cur - start))
			start = cur + 1
		cur += 1
	if cur > start:
		argv.append(line.substr(start, cur))
	return argv


## Converts arguments from String to types expected by the callable, and returns true if successful.
## The converted values are placed into a separate r_args array.
func _parse_argv(p_argv: PackedStringArray, p_callable: Callable, r_args: Array) -> bool:
	var passed := true

	var method_info: Dictionary = _get_method_info(p_callable)
	if method_info.is_empty():
		error("Couldn't find method info for: " + p_callable.get_method())
		return false

	var num_args: int = p_argv.size() - 1
	var max_args: int = method_info.args.size()
	var num_with_defaults: int = method_info.default_args.size()
	var required_args: int = max_args - num_with_defaults
	if num_args < required_args:
		error("Missing arguments.")
		return false
	if num_args > max_args:
		error("Too many arguments.")
		return false

	r_args.resize(p_argv.size() - 1)
	for i in range(1, p_argv.size()):
		var a: String = p_argv[i]
		var incorrect_type := false
		var expected_type: int = method_info.args[i - 1].type

		if expected_type == TYPE_STRING:
			r_args[i - 1] = a.trim_prefix("\"").trim_suffix("\"")
		elif a.is_valid_float():
			r_args[i - 1] = a.to_float()
		elif a.is_valid_int():
			r_args[i - 1] = a.to_int()
		elif a == "true" or a == "1" or a == "yes":
			r_args[i - 1] = true
		elif a == "false" or a == "0" or a == "no":
			r_args[i - 1] = false
		else:
			r_args[i - 1] = a.trim_prefix("\"").trim_suffix("\"")

		var parsed_type: int = typeof(r_args[i - 1])

		if not _are_compatible_types(expected_type, parsed_type):
			error("Argument %d expects %s, but %s provided." % [i, type_string(expected_type), type_string(parsed_type)])
			passed = false

	return passed


## Returns true if the parsed type is compatible with the expected type.
func _are_compatible_types(p_expected_type: int, p_parsed_type: int) -> bool:
	return p_expected_type == p_parsed_type or \
		p_expected_type == TYPE_NIL or \
		p_expected_type == TYPE_STRING or \
		p_expected_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and p_parsed_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]


## Returns true if the callable can be registered as a command.
func _validate_callable(p_callable: Callable) -> bool:
	var method_info: Dictionary = _get_method_info(p_callable)
	if method_info.is_empty():
		error("Couldn't find method info for: " + p_callable.get_method())
		return false

	var ret := true
	for arg in method_info.args:
		if not arg.type in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			error("Unsupported argument type: %s is %s" % [arg.name, type_string(arg.type)])
			ret = false
	return ret


func _get_method_info(p_callable: Callable) -> Dictionary:
	var method_info: Dictionary
	var method_list: Array[Dictionary]
	method_list = p_callable.get_object().get_method_list()
	for m in method_list:
		if m.name == p_callable.get_method():
			method_info = m
			break
	return method_info


## Prints the help text for the given command.
func _usage(p_command_name: String) -> void:
	if not is_command_registered(p_command_name):
		error("Command not found: " + _format_name(p_command_name))
		_suggest_similar(_parse_command_line(_history[_history.size() - 1]), 1)
		return

	var dealiased_name: String = _command_aliases.get(p_command_name, p_command_name)
	if dealiased_name != p_command_name:
		_print_line("Alias of " + _format_name(dealiased_name) + ".")

	var callable: Callable = _commands[dealiased_name]
	var method_info: Dictionary = _get_method_info(callable)
	if method_info.is_empty():
		error("Couldn't find method info for: " + callable.get_method())
		_print_line("Usage: ???")
		return

	var usage_line: String = "Usage: %s" % [dealiased_name]
	var arg_lines: String = ""
	var required_args: int = method_info.args.size() - method_info.default_args.size()

	for i in range(method_info.args.size()):
		var arg_name: String = method_info.args[i].name.trim_prefix("p_")
		var arg_type: int = method_info.args[i].type
		if i < required_args:
			usage_line += " " + arg_name
		else:
			usage_line += " [lb]" + arg_name + "[rb]"
		var def_spec: String = ""
		var num_required_args: int = method_info.args.size() - method_info.default_args.size()
		if i >= num_required_args:
			var def_value = method_info.default_args[i - num_required_args]
			if typeof(def_value) == TYPE_STRING:
				def_value = "\"" + def_value + "\""
			def_spec = " = %s" % [def_value]
		arg_lines += "  %s: %s%s\n" % [arg_name, type_string(arg_type) if arg_type != TYPE_NIL else "Variant", def_spec]

	_print_line(usage_line)

	var desc_line: String = ""
	desc_line = _command_descriptions.get(dealiased_name, "")
	if not desc_line.is_empty():
		desc_line[0] = desc_line[0].capitalize()
		if desc_line.right(1) != ".":
			desc_line += "."
		_print_line(desc_line)

	if not arg_lines.is_empty():
		_print_line("Arguments:")
		_print_line(arg_lines)


func _fill_command_line(p_line: String) -> void:
	_command_line.text = p_line
	_command_line.set_deferred(&"caret_column", p_line.length())


func _fill_from_history() -> void:
	_hist_idx = wrapi(_hist_idx, -1, _history.size())
	if _hist_idx < 0:
		_fill_command_line("")
	else:
		_fill_command_line(_history[_history.size() - _hist_idx - 1])


func _push_history(p_line: String) -> void:
	var idx: int = _history.find(p_line)
	if idx != -1:
		_history.remove_at(idx)
	_history.append(p_line)
	_hist_idx = -1


## Auto-completes a command or auto-correction on TAB.
func _autocomplete() -> void:
	if _autocomplete_matches.is_empty():
		var entry: String = _command_line.text
		for k in _commands:
			if k.begins_with(entry):
				_autocomplete_matches.append(k)
		_autocomplete_matches.sort()
	if not _autocomplete_matches.is_empty():
		var match: String = _autocomplete_matches[0]
		_fill_command_line(match)
		_autocomplete_matches.remove_at(0)
		_autocomplete_matches.push_back(match)


## Suggests a similar command to the user and prepares the auto-correction on TAB.
func _suggest_similar(p_argv: PackedStringArray, p_command_index: int = 0) -> void:
	var fuzzy_hit: String = _fuzzy_match_command(p_argv[p_command_index], 2)
	if fuzzy_hit:
		info("Did you mean %s? %s" % [_format_name(fuzzy_hit), _format_tip("([b]TAB[/b] to fill)")])
		var argv := p_argv.duplicate()
		argv[p_command_index] = fuzzy_hit
		var suggest_command: String = " ".join(argv)
		suggest_command = suggest_command.strip_edges()
		_autocomplete_matches.append.call_deferred(suggest_command)


## Finds a command with a similar name.
func _fuzzy_match_command(p_name: String, p_max_edit_distance: int) -> String:
	var command_names: PackedStringArray = _commands.keys()
	command_names.append_array(_command_aliases.keys())
	command_names.sort()
	var best_distance: int = 9223372036854775807
	var best_name: String = ""
	for n: String in command_names:
		var dist: float = _calculate_osa_distance(p_name, n)
		if dist < best_distance:
			best_distance = dist
			best_name = n
	# debug("Best %s: %d" % [best_name, best_distance])
	return best_name if best_distance <= p_max_edit_distance else ""


## Calculates optimal string alignment distance [br]
## See: https://en.wikipedia.org/wiki/Levenshtein_distance
func _calculate_osa_distance(s1: String, s2: String) -> int:
	var s1_len: int = s1.length()
	var s2_len: int = s2.length()

	# Iterative approach with 3 matrix rows.
	# Most of the work is done on row1 and row2 - row0 is only needed to calculate transpostition cost.
	var row0: PackedInt32Array # previos-previous
	var row1: PackedInt32Array # previous
	var row2: PackedInt32Array # current aka the one we need to calculate
	row0.resize(s2_len + 1)
	row1.resize(s2_len + 1)
	row2.resize(s2_len + 1)

	# edit distance is the number of characters to insert to get from empty string to s2
	for i in range(s2_len + 1):
		row1[i] = i

	for i in range(s1_len):
		# edit distance is the number of characters to delete from s1 to match empty s2
		row2[0] = i + 1

		for j in range(s2_len):
			var deletion_cost: int = row1[j + 1] + 1
			var insertion_cost: int = row2[j] + 1
			var substitution_cost: int = row1[j] if s1[i] == s2[j] else row1[j] + 1

			row2[j + 1] = min(deletion_cost, insertion_cost, substitution_cost)

			if i > 1 and j > 1 and s1[i - 1] == s2[j] and s1[i - 1] == s2[j]:
				var transposition_cost: int = row0[j - 1] + 1
				row2[j + 1] = mini(transposition_cost, row2[j + 1])

		# Swap rows.
		var tmp: PackedInt32Array = row0
		row0 = row1
		row1 = row2
		row2 = tmp
	return row1[s2_len]


## Formats the command name for display.
func _format_name(p_name: String) -> String:
	return "[color=" + _color_command_mention.to_html() + "]" + p_name + "[/color]"


## Formats the helpful tip text (hopefully).
func _format_tip(p_text: String) -> String:
	return "[i][color=" + _color_debug.to_html() + "]" + p_text + "[/color][/i]"


func _on_command_line_submitted(p_command: String) -> void:
	execute_command(p_command)
	_fill_command_line("")
	_autocomplete_matches.clear()


func _on_command_line_changed(p_line: String) -> void:
	_autocomplete_matches.clear()


# *** BUILT-IN COMMANDS


func _cmd_aliases() -> void:
	info("Aliases:")
	var aliases: Array = _command_aliases.keys()
	aliases.sort()
	for alias in aliases:
		var dealiased_name = _command_aliases.get(alias, alias)
		var desc: String = _command_descriptions.get(dealiased_name, "")
		info(_format_name(alias) if desc.is_empty() else "%s -- same as %s; %s" % [_format_name(alias), _format_name(dealiased_name), desc])


func _cmd_commands() -> void:
	info("Available commands:")
	var command_names: Array = _commands.keys()
	command_names.sort()
	for name in command_names:
		var desc: String = _command_descriptions.get(name, "")
		info(_format_name(name) if desc.is_empty() else "%s -- %s" % [_format_name(name), desc])


func _cmd_fps_max(p_limit: int = -1) -> void:
	if p_limit < 0:
		if Engine.max_fps == 0:
			info("Framerate is unlimited.")
		else:
			info("Framerate is limited to %d FPS." % [Engine.max_fps])
		return

	Engine.max_fps = p_limit
	if p_limit > 0:
		info("Limiting framerate to %d FPS." % [p_limit])
	elif p_limit == 0:
		info("Removing framerate limits.")


func _cmd_fullscreen() -> void:
	if get_viewport().mode == Window.MODE_WINDOWED:
		# get_viewport().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		get_viewport().mode = Window.MODE_FULLSCREEN
		info("Window switched to fullscreen mode.")
	else:
		get_viewport().mode = Window.MODE_WINDOWED
		info("Window switched to windowed mode.")


func _cmd_help(p_command_name: String = "") -> void:
	if p_command_name.is_empty():
		_print_line(_format_tip("Type %s to list all available commands." % [_format_name("commands")]))
		_print_line(_format_tip("Type %s to get more info about the command." % [_format_name("help command")]))
	else:
		_usage(p_command_name)


func _cmd_quit() -> void:
	get_tree().quit()


func _cmd_vsync(p_mode: int = -1) -> void:
	if p_mode < 0:
		var current: int = DisplayServer.window_get_vsync_mode()
		if current == 0:
			info("V-Sync: disabled.")
		elif current == 1:
			info('V-Sync: enabled.')
		elif current == 2:
			info('Current V-Sync mode: adaptive.')
		info("Adjust V-Sync mode with an argument: 0 - disabled, 1 - enabled, 2 - adaptive.")
	elif p_mode == DisplayServer.VSYNC_DISABLED:
		info("Changing to disabled.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	elif p_mode == DisplayServer.VSYNC_ENABLED:
		info("Changing to default V-Sync.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	elif p_mode == DisplayServer.VSYNC_ADAPTIVE:
		info("Changing to adaptive V-Sync.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	else:
		error("Invalid mode.")
		info("Acceptable modes: 0 - disabled, 1 - enabled, 2 - adaptive.")
