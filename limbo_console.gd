extends CanvasLayer
## LimboConsole

signal toggled(is_shown)

const THEME_DEFAULT := "res://addons/limbo_console/res/default_theme.tres"
const HISTORY_FILE := "user://limbo_console_history.log"

const AsciiArt := preload("res://addons/limbo_console/ascii_art.gd")
const BuiltinCommands := preload("res://addons/limbo_console/builtin_commands.gd")
const CommandEntry := preload("res://addons/limbo_console/command_entry.gd")
const ConfigMapper := preload("res://addons/limbo_console/config_mapper.gd")
const ConsoleOptions := preload("res://addons/limbo_console/console_options.gd")
const Util := preload("res://addons/limbo_console/util.gd")

## If false, prevents console from being shown. Commands can still be executed from code.
var enabled: bool = true:
	set(value):
		enabled = value
		set_process_input(enabled)
		if not enabled and _control.visible:
			_is_opening = false
			set_process(false)
			_hide_console()

var _control: Control
var _control_block: Control
var _output: RichTextLabel
var _entry: CommandEntry
var _previous_gui_focus: Control

# Theme colors
var _output_command_color: Color
var _output_command_mention_color: Color
var _output_error_color: Color
var _output_warning_color: Color
var _output_text_color: Color
var _output_debug_color: Color
var _entry_text_color: Color
var _entry_hint_color: Color
var _entry_command_found_color: Color
var _entry_command_not_found_color: Color

var _options: ConsoleOptions
var _commands: Dictionary # command_name => Callable
var _aliases: Dictionary # alias_name => command_to_run: PackedStringArray
var _command_descriptions: Dictionary # command_name => description_text
var _argument_autocomplete_sources: Dictionary # [command_name, arg_idx] => Callable
var _history: PackedStringArray
var _hist_idx: int = -1
var _autocomplete_matches: PackedStringArray
var _eval_inputs: Dictionary
var _silent: bool = false
var _was_already_paused: bool = false

var _open_t: float = 0.0
var _open_speed: float = 5.0
var _is_opening: bool = false


func _init() -> void:
	layer = 9999
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

	_options = ConsoleOptions.new()
	ConfigMapper.load_from_config(_options)

	_build_gui()
	_init_theme()
	_control.hide()
	_control_block.hide()

	_open_speed = _options.open_speed

	if _options.persist_history:
		_load_history()

	if _options.disable_in_release_build:
		enabled = OS.is_debug_build()

	_entry.text_submitted.connect(_on_entry_text_submitted)
	_entry.text_changed.connect(_on_entry_text_changed)


func _ready() -> void:
	set_process(false) # Note, if you do it in _init(), it won't actually stop it for some reason.
	BuiltinCommands.register_commands()
	if _options.greet_user:
		_greet()
	_add_aliases_from_config.call_deferred()
	_run_autoexec_script.call_deferred()
	_entry.autocomplete_requested.connect(_autocomplete)


func _exit_tree() -> void:
	if _options.persist_history:
		_save_history()


func _input(p_event: InputEvent) -> void:
	if p_event.is_echo():
		return
	if p_event.is_action_pressed("limbo_console_toggle"):
		toggle_console()
		get_viewport().set_input_as_handled()
	elif _control.visible and p_event is InputEventKey and p_event.is_pressed():
		var handled := true
		if not _is_opening:
			pass # Don't accept input while closing console.
		elif p_event.keycode == KEY_UP:
			_hist_idx += 1
			_fill_entry_from_history()
		elif p_event.keycode == KEY_DOWN:
			_hist_idx -= 1
			_fill_entry_from_history()
		elif p_event.keycode == KEY_TAB:
			_autocomplete()
		elif p_event.keycode == KEY_PAGEUP:
			var scroll_bar: VScrollBar = _output.get_v_scroll_bar()
			scroll_bar.value -= scroll_bar.page
		elif p_event.keycode == KEY_PAGEDOWN:
			var scroll_bar: VScrollBar = _output.get_v_scroll_bar()
			scroll_bar.value += scroll_bar.page
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var done_sliding := false
	if _is_opening:
		_open_t = move_toward(_open_t, 1.0, _open_speed * delta)
		if _open_t == 1:
			done_sliding = true
	else: # We close faster than opening.
		_open_t = move_toward(_open_t, 0.0, _open_speed * delta * 1.5)
		if _open_t == 0:
			done_sliding = true

	var eased := ease(_open_t, -1.75)
	var new_y := remap(eased, 0, 1, -_control.size.y, 0)
	_control.position.y = new_y

	if done_sliding:
		set_process(false)
		if not _is_opening:
			_hide_console()


# *** PUBLIC INTERFACE


func open_console() -> void:
	if enabled:
		_is_opening = true
		set_process(true)
		_show_console()


func close_console() -> void:
	if enabled:
		_is_opening = false
		set_process(true)
		# _hide_console() is called in _process()


func is_visible() -> bool:
	return _control.visible


func toggle_console() -> void:
	if _is_opening:
		close_console()
	else:
		open_console()


## Clears all messages in the console.
func clear_console() -> void:
	_output.text = ""


## Prints an info message to the console and the output.
func info(p_line: String) -> void:
	print_line(p_line)


## Prints an error message to the console and the output.
func error(p_line: String) -> void:
	print_line("[color=%s]ERROR:[/color] %s" % [_output_error_color.to_html(), p_line])


## Prints a warning message to the console and the output.
func warn(p_line: String) -> void:
	print_line("[color=%s]WARNING:[/color] %s" % [_output_warning_color.to_html(), p_line])


## Prints a debug message to the console and the output.
func debug(p_line: String) -> void:
	print_line("[color=%s]DEBUG: %s[/color]" % [_output_debug_color.to_html(), p_line])


## Prints a line using boxed ASCII art style.
func print_boxed(p_line: String) -> void:
	for line in AsciiArt.str_to_boxed_art(p_line):
		print_line(line)


## Prints a line to the console, and optionally to standard output.
func print_line(p_line: String, p_stdout: bool = _options.print_to_stdout) -> void:
	if _silent:
		return
	_output.text += p_line + "\n"
	if p_stdout:
		print(Util.bbcode_strip(p_line))


## Registers a new command for the specified callable. [br]
## Optionally, you can provide a name and a description.
func register_command(p_func: Callable, p_name: String = "", p_desc: String = "") -> void:
	if not _validate_callable(p_func):
		push_error("LimboConsole: Failed to register command: %s" % [p_func if p_name.is_empty() else p_name])
		return
	var name: String = p_name
	if name.is_empty():
		name = p_func.get_method().trim_prefix("_").trim_prefix("cmd_")
	if _commands.has(name):
		push_error("LimboConsole: Command already registered: " + p_name)
		return
	# Note: It should be possible to have an alias with the same name.
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
		push_error("LimboConsole: Unregister failed - command not found: " % [p_func_or_name])
		return

	_commands.erase(cmd_name)
	_command_descriptions.erase(cmd_name)

	for i in range(1, 5):
		_argument_autocomplete_sources.erase([cmd_name, i])


## Is a command or an alias registered by the given name.
func has_command(p_name: String) -> bool:
	return _commands.has(p_name)


func get_command_names(p_include_aliases: bool = false) -> PackedStringArray:
	var names: PackedStringArray = _commands.keys()
	if p_include_aliases:
		names.append_array(_aliases.keys())
	names.sort()
	return names


func get_command_description(p_name: String) -> String:
	return _command_descriptions.get(p_name, "")


## Registers an alias for a command (may include arguments).
func add_alias(p_alias: String, p_command_to_run: String) -> void:
	if not p_alias.is_valid_identifier():
		error("Invalid alias identifier.")
		return
	# It should be possible to override commands and existing aliases.
	# It should be possible to create aliases for commands that are not yet registered,
	# because some commands may be registered by local-to-scene scripts.
	_aliases[p_alias] = _parse_command_line(p_command_to_run)


## Removes an alias by name.
func remove_alias(p_name: String) -> void:
	_aliases.erase(p_name)


## Is an alias registered by the given name.
func has_alias(p_name: String) -> bool:
	return _aliases.has(p_name)


## Lists all registered aliases.
func get_aliases() -> PackedStringArray:
	return PackedStringArray(_aliases.keys())


## Returns the alias's actual command as an argument vector.
func get_alias_argv(p_alias: String) -> PackedStringArray:
	return _aliases.get(p_alias, [p_alias]).duplicate()


## Registers a callable that should return an array of possible values for the given argument and command.
## It will be used for autocompletion.
func add_argument_autocomplete_source(p_command: String, p_argument: int, p_source: Callable) -> void:
	if not p_source.is_valid():
		push_error("LimboConsole: Can't add autocomplete source: source callable is not valid")
		return
	if not has_command(p_command):
		push_error("LimboConsole: Can't add autocomplete source: command doesn't exist: ", p_command)
		return
	if p_argument < 1 or p_argument > 5:
		push_error("LimboConsole: Can't add autocomplete source: argument index out of bounds: ", p_argument)
		return
	var key := [p_command, p_argument]
	_argument_autocomplete_sources[key] = p_source


## Parses the command line and executes the command if it's valid.
func execute_command(p_command_line: String, p_silent: bool = false) -> void:
	p_command_line = p_command_line.strip_edges()
	if p_command_line.is_empty() or p_command_line.strip_edges().begins_with('#'):
		return

	var argv: PackedStringArray = _parse_command_line(p_command_line)
	var expanded_argv: PackedStringArray = _expand_alias(argv)
	var command_name: String = expanded_argv[0]
	var command_args: Array = []

	_silent = p_silent
	if not p_silent:
		var history_line: String = " ".join(argv)
		_push_history(history_line)
		info("[color=%s][b]>[/b] %s[/color] %s" %
				[_output_command_color.to_html(), argv[0], " ".join(argv.slice(1))])

	if not has_command(command_name):
		error("Unknown command: " + command_name)
		_suggest_similar_command(expanded_argv)
		_silent = false
		return

	var cmd: Callable = _commands.get(command_name)
	var valid: bool = _parse_argv(expanded_argv, cmd, command_args)
	if valid:
		var err = cmd.callv(command_args)
		var failed: bool = typeof(err) == TYPE_INT and err > 0
		if failed:
			_suggest_argument_corrections(expanded_argv)
	else:
		usage(argv[0])
	if _options.sparse_mode:
		print_line("")
	_silent = false


## Execute commands from file.
func execute_script(p_file: String, p_silent: bool = true) -> void:
	if FileAccess.file_exists(p_file):
		if not p_silent:
			LimboConsole.info("Executing " + p_file);
		var fa := FileAccess.open(p_file, FileAccess.READ)
		while not fa.eof_reached():
			var line: String = fa.get_line()
			LimboConsole.execute_command(line, p_silent)
	else:
		LimboConsole.error("File not found: " + p_file.trim_prefix("user://"))


## Formats the tip text (hopefully useful ;).
func format_tip(p_text: String) -> String:
	return "[i][color=" + _output_debug_color.to_html() + "]" + p_text + "[/color][/i]"


## Formats the command name for display.
func format_name(p_name: String) -> String:
	return "[color=" + _output_command_mention_color.to_html() + "]" + p_name + "[/color]"


## Prints the help text for the given command.
func usage(p_command: String) -> Error:
	if _aliases.has(p_command):
		var alias_argv: PackedStringArray = get_alias_argv(p_command)
		var formatted_cmd := "%s %s" % [format_name(alias_argv[0]), ' '.join(alias_argv.slice(1))]
		print_line("Alias of: " + formatted_cmd)
		p_command = alias_argv[0]

	if not has_command(p_command):
		error("Command not found: " + p_command)
		return ERR_INVALID_PARAMETER

	var callable: Callable = _commands[p_command]
	var method_info: Dictionary = Util.get_method_info(callable)
	if method_info.is_empty():
		error("Couldn't find method info for: " + callable.get_method())
		print_line("Usage: ???")

	var usage_line: String = "Usage: %s" % [p_command]
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
	arg_lines = arg_lines.trim_suffix('\n')

	print_line(usage_line)

	var desc_line: String = ""
	desc_line = _command_descriptions.get(p_command, "")
	if not desc_line.is_empty():
		desc_line[0] = desc_line[0].capitalize()
		if desc_line.right(1) != ".":
			desc_line += "."
		print_line(desc_line)

	if not arg_lines.is_empty():
		print_line("Arguments:")
		print_line(arg_lines)
	return OK


## Define an input variable for "eval" command.
func add_eval_input(p_name: String, p_value) -> void:
	_eval_inputs[p_name] = p_value


## Remove specified input variable from "eval" command.
func remove_eval_input(p_name) -> void:
	_eval_inputs.erase(p_name)


## List the defined input variables used in "eval" command.
func get_eval_input_names() -> PackedStringArray:
	return _eval_inputs.keys()


## Get input variable values used in "eval" command, listed in the same order as names.
func get_eval_inputs() -> Array:
	return _eval_inputs.values()


## Define the object that will be used as the base instance for "eval" command.
## When defined, this object will be the "self" for expressions.
## Can be null (the default) to not use any base instance.
func set_eval_base_instance(object):
	_eval_inputs["_base_instance"] = object


## Get the object that will be used as the base instance for "eval" command.
## Null by default.
func get_eval_base_instance():
	return _eval_inputs.get("_base_instance")


# *** PRIVATE

# *** INITIALIZATION


func _build_gui() -> void:
	var con := Control.new() # To block mouse input.
	_control_block = con
	con.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(con)

	var panel := PanelContainer.new()
	_control = panel
	panel.anchor_bottom = _options.height_ratio
	panel.anchor_right = 1.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_active = true
	_output.scroll_following = true
	_output.bbcode_enabled = true
	_output.focus_mode = Control.FOCUS_CLICK
	vbox.add_child(_output)

	_entry = CommandEntry.new()
	vbox.add_child(_entry)

	_control.modulate = Color(1.0, 1.0, 1.0, _options.opacity)


func _init_theme() -> void:
	var theme: Theme
	if ResourceLoader.exists(_options.custom_theme, "Theme"):
		theme = load(_options.custom_theme)
	else:
		theme = load(THEME_DEFAULT)
	_control.theme = theme

	const CONSOLE_COLORS_THEME_TYPE := &"ConsoleColors"
	_output_command_color = theme.get_color(&"output_command_color", CONSOLE_COLORS_THEME_TYPE)
	_output_command_mention_color = theme.get_color(&"output_command_mention_color", CONSOLE_COLORS_THEME_TYPE)
	_output_text_color = theme.get_color(&"output_text_color", CONSOLE_COLORS_THEME_TYPE)
	_output_error_color = theme.get_color(&"output_error_color", CONSOLE_COLORS_THEME_TYPE)
	_output_warning_color = theme.get_color(&"output_warning_color", CONSOLE_COLORS_THEME_TYPE)
	_output_debug_color = theme.get_color(&"output_debug_color", CONSOLE_COLORS_THEME_TYPE)
	_entry_text_color = theme.get_color(&"entry_text_color", CONSOLE_COLORS_THEME_TYPE)
	_entry_hint_color = theme.get_color(&"entry_hint_color", CONSOLE_COLORS_THEME_TYPE)
	_entry_command_found_color = theme.get_color(&"entry_command_found_color", CONSOLE_COLORS_THEME_TYPE)
	_entry_command_not_found_color = theme.get_color(&"entry_command_not_found_color", CONSOLE_COLORS_THEME_TYPE)

	_output.add_theme_color_override(&"default_color", _output_text_color)
	_entry.add_theme_color_override(&"font_color", _entry_text_color)
	_entry.add_theme_color_override(&"hint_color", _entry_hint_color)
	_entry.syntax_highlighter.command_found_color = _entry_command_found_color
	_entry.syntax_highlighter.command_not_found_color = _entry_command_not_found_color
	_entry.syntax_highlighter.text_color = _entry_text_color


func _greet() -> void:
	var message: String = _options.greeting_message
	message = message.format({
		"project_name": ProjectSettings.get_setting("application/config/name"),
		"project_version": ProjectSettings.get_setting("application/config/version"),
		})
	if not message.is_empty():
		if _options.greet_using_ascii_art and AsciiArt.is_boxed_art_supported(message):
			print_boxed(message)
			info("")
		else:
			info("[b]" + message + "[/b]")
	BuiltinCommands.cmd_help()
	info(format_tip("-----"))


func _add_aliases_from_config() -> void:
	for alias in _options.aliases:
		var target = _options.aliases[alias]
		if not alias is String:
			push_error("LimboConsole: Config error: Alias name should be String")
		elif not target is String:
			push_error("LimboConsole: Config error: Alias target should be String")
		elif has_command(alias):
			push_error("LimboConsole: Config error: Alias or command already registered: ", alias)
		elif not has_command(target):
			push_error("LimboConsole: Config error: Alias target not found: ", target)
		else:
			add_alias(alias, target)


func _run_autoexec_script() -> void:
	if _options.autoexec_script.is_empty():
		return
	if _options.autoexec_auto_create and not FileAccess.file_exists(_options.autoexec_script):
		FileAccess.open(_options.autoexec_script, FileAccess.WRITE)
	if FileAccess.file_exists(_options.autoexec_script):
		execute_script(_options.autoexec_script)


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


# *** PARSING


## Splits the command line string into an array of arguments (aka argv).
func _parse_command_line(p_line: String) -> PackedStringArray:
	var argv: PackedStringArray = []
	var arg: String = ""
	var in_quotes: bool = false
	var in_brackets: bool = false
	var line: String = p_line.strip_edges()
	var start: int = 0
	var cur: int = 0
	for char in line:
		if char == '"':
			in_quotes = not in_quotes
		elif char == '(':
			in_brackets = true
		elif char == ')':
			in_brackets = false
		elif char == ' ' and not in_quotes and not in_brackets:
			if cur > start:
				argv.append(line.substr(start, cur - start))
			start = cur + 1
		cur += 1
	if cur > start:
		argv.append(line.substr(start, cur))
	return argv


## Substitutes alias with its real command in argv.
func _expand_alias(p_argv: PackedStringArray) -> PackedStringArray:
	if p_argv.size() > 0 and _aliases.has(p_argv[0]):
		return _aliases.get(p_argv[0]) + p_argv.slice(1)
	else:
		return p_argv


## Converts arguments from String to types expected by the callable, and returns true if successful.
## The converted values are placed into a separate r_args array.
func _parse_argv(p_argv: PackedStringArray, p_callable: Callable, r_args: Array) -> bool:
	var passed := true

	var method_info: Dictionary = Util.get_method_info(p_callable)
	if method_info.is_empty():
		error("Couldn't find method info for: " + p_callable.get_method())
		return false

	var num_args: int = p_argv.size() - 1
	var max_args: int = method_info.args.size()
	var num_with_defaults: int = method_info.default_args.size()
	var required_args: int = max_args - num_with_defaults

	# Join all arguments into a single string if the callable accepts a single string argument.
	if max_args == 1 and method_info.args[0].type == TYPE_STRING:
		var a: String = " ".join(p_argv.slice(1))
		if a.left(1) == '"' and a.right(1) == '"':
			a = a.trim_prefix('"').trim_suffix('"')
		r_args.append(a)
		return true
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
			if a.left(1) == '"' and a.right(1) == '"':
				a = a.trim_prefix('"').trim_suffix('"')
			r_args[i - 1] = a
		elif a.begins_with('(') and a.ends_with(')'):
			var vec = _parse_vector_arg(a)
			if vec != null:
				r_args[i - 1] = vec
			else:
				r_args[i - 1] = a
				passed = false
		elif a.is_valid_float():
			r_args[i - 1] = a.to_float()
		elif a.is_valid_int():
			r_args[i - 1] = a.to_int()
		elif a == "true" or a == "1" or a == "yes":
			r_args[i - 1] = true
		elif a == "false" or a == "0" or a == "no":
			r_args[i - 1] = false
		else:
			r_args[i - 1] = a.trim_prefix('"').trim_suffix('"')

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
		(p_expected_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and p_parsed_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]) or \
		(p_expected_type in [TYPE_VECTOR2, TYPE_VECTOR2I] and p_parsed_type in [TYPE_VECTOR2, TYPE_VECTOR2I]) or \
		(p_expected_type in [TYPE_VECTOR3, TYPE_VECTOR3I] and p_parsed_type in [TYPE_VECTOR3, TYPE_VECTOR3I]) or \
		(p_expected_type in [TYPE_VECTOR4, TYPE_VECTOR4I] and p_parsed_type in [TYPE_VECTOR4, TYPE_VECTOR4I])


func _parse_vector_arg(p_text):
	assert(p_text.begins_with('(') and p_text.ends_with(')'), "Vector string presentation must begin and end with round brackets")
	var comp: Array
	var token: String
	for i in range(1, p_text.length()):
		var c: String = p_text[i]
		if c.is_valid_int() or c == '.' or c == '-':
			token += c
		elif c == ',' or c == ' ' or c == ')':
			if token.is_empty() and c == ',' and p_text[i - 1] in [',', '(']:
				# Support shorthand notation: (,,1) => (0,0,1)
				token = '0'
			if token.is_valid_float():
				comp.append(token.to_float())
				token = ""
			elif not token.is_empty():
				error("Failed to parse vector argument: Not a number: \"" + token + "\"")
				info(format_tip("Tip: Supported formats are (1, 2, 3) and (1 2 3) with 2, 3 and 4 elements."))
				return null
		else:
			error("Failed to parse vector argument: Bad formatting: \"" + p_text + "\"")
			info(format_tip("Tip: Supported formats are (1, 2, 3) and (1 2 3) with 2, 3 and 4 elements."))
			return null
	if comp.size() == 2:
		return Vector2(comp[0], comp[1])
	elif comp.size() == 3:
		return Vector3(comp[0], comp[1], comp[2])
	elif comp.size() == 4:
		return Vector4(comp[0], comp[1], comp[2], comp[3])
	else:
		error("LimboConsole supports 2,3,4-element vectors, but %d-element vector given." % [comp.size()])
		return null


# *** AUTOCOMPLETE


## Auto-completes a command or auto-correction on TAB.
func _autocomplete() -> void:
	if not _autocomplete_matches.is_empty():
		var match: String = _autocomplete_matches[0]
		_fill_entry(match)
		_autocomplete_matches.remove_at(0)
		_autocomplete_matches.push_back(match)
		_update_autocomplete()


## Updates autocomplete suggestions and hint based on user input.
func _update_autocomplete() -> void:
	var argv: PackedStringArray = _expand_alias(_parse_command_line(_entry.text))
	if _entry.text.right(1) == ' ' or argv.size() == 0:
		argv.append("")
	var command_name: String = argv[0]
	var last_arg: int = argv.size() - 1

	if _autocomplete_matches.is_empty() and not _entry.text.is_empty():
		if last_arg == 0:
			# Command name
			var line: String = _entry.text
			for k in get_command_names(true):
				if k.begins_with(line):
					_autocomplete_matches.append(k)
			_autocomplete_matches.sort()
		else:
			# Arguments
			var key := [command_name, last_arg]
			if _argument_autocomplete_sources.has(key) and not argv[last_arg].is_empty():
				var argument_values = _argument_autocomplete_sources[key].call()
				if typeof(argument_values) < TYPE_ARRAY:
					push_error("LimboConsole: Argument autocomplete source returned unsupported type: ",
							type_string(typeof(argument_values)), " command: ", command_name)
					argument_values = []
				var matches: PackedStringArray = []
				for value in argument_values:
					if str(value).begins_with(argv[last_arg]):
						matches.append(_entry.text.substr(0, _entry.text.length() - argv[last_arg].length()) + str(value))
				matches.sort()
				_autocomplete_matches.append_array(matches)
			# History
			for i in range(_history.size() - 1, -1, -1):
				if _history[i].begins_with(_entry.text):
					_autocomplete_matches.append(_history[i])

	if _autocomplete_matches.size() > 0 \
			and _autocomplete_matches[0].length() > _entry.text.length() \
			and _autocomplete_matches[0].begins_with(_entry.text):
		_entry.autocomplete_hint = _autocomplete_matches[0].substr(_entry.text.length())
	else:
		_entry.autocomplete_hint = ""


func _clear_autocomplete() -> void:
	_autocomplete_matches.clear()
	_entry.autocomplete_hint = ""


## Suggests corrections to user input based on similar command names.
func _suggest_similar_command(p_argv: PackedStringArray) -> void:
	if _silent:
		return
	var fuzzy_hit: String = Util.fuzzy_match_string(p_argv[0], 2, get_command_names(true))
	if fuzzy_hit:
		info(format_tip("Did you mean %s? ([b]TAB[/b] to fill)" % [format_name(fuzzy_hit)]))
		var argv := p_argv.duplicate()
		argv[0] = fuzzy_hit
		var suggest_command: String = " ".join(argv)
		suggest_command = suggest_command.strip_edges()
		_autocomplete_matches.append(suggest_command)


## Suggests corrections to user input based on similar autocomplete argument values.
func _suggest_argument_corrections(p_argv: PackedStringArray) -> void:
	if _silent:
		return
	var argv: PackedStringArray
	var command_name: String = p_argv[0]
	command_name = get_alias_argv(command_name)[0]
	var corrected := false

	argv.resize(p_argv.size())
	argv[0] = command_name
	for i in range(1, p_argv.size()):
		var accepted_values = []
		var key := [command_name, i]
		var source: Callable = _argument_autocomplete_sources.get(key, Callable())
		if source.is_valid():
			accepted_values = source.call()
		if accepted_values == null or typeof(accepted_values) < TYPE_ARRAY:
			continue
		var fuzzy_hit: String = Util.fuzzy_match_string(p_argv[i], 2, accepted_values)
		if not fuzzy_hit.is_empty():
			argv[i] = fuzzy_hit
			corrected = true
		else:
			argv[i] = p_argv[i]
	if corrected:
		info(format_tip("Did you mean \"%s %s\"? ([b]TAB[/b] to fill)" % [format_name(command_name), " ".join(argv.slice(1))]))
		var suggest_command: String = " ".join(argv)
		suggest_command = suggest_command.strip_edges()
		_autocomplete_matches.append(suggest_command)


# *** MISC


func _show_console() -> void:
	if not _control.visible and enabled:
		_control.show()
		_control_block.show()
		_was_already_paused = get_tree().paused
		if not _was_already_paused:
			get_tree().paused = true
		_previous_gui_focus = get_viewport().gui_get_focus_owner()
		_entry.grab_focus()
		toggled.emit(true)


func _hide_console() -> void:
	if _control.visible:
		_control.hide()
		_control_block.hide()
		if not _was_already_paused:
			get_tree().paused = false
		if is_instance_valid(_previous_gui_focus):
			_previous_gui_focus.grab_focus()
		toggled.emit(false)


## Returns true if the callable can be registered as a command.
func _validate_callable(p_callable: Callable) -> bool:
	var method_info: Dictionary = Util.get_method_info(p_callable)
	if method_info.is_empty():
		push_error("LimboConsole: Couldn't find method info for: " + p_callable.get_method())
		return false

	var ret := true
	for arg in method_info.args:
		if not arg.type in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I]:
			push_error("LimboConsole: Unsupported argument type: %s is %s" % [arg.name, type_string(arg.type)])
			ret = false
	return ret


func _fill_entry(p_line: String) -> void:
	_entry.text = p_line
	_entry.set_caret_column(p_line.length())


func _fill_entry_from_history() -> void:
	_hist_idx = wrapi(_hist_idx, -1, _history.size())
	if _hist_idx < 0:
		_fill_entry("")
	else:
		_fill_entry(_history[_history.size() - _hist_idx - 1])
	_clear_autocomplete()
	_update_autocomplete()


func _push_history(p_line: String) -> void:
	var idx: int = _history.find(p_line)
	if idx != -1:
		_history.remove_at(idx)
	_history.append(p_line)
	_hist_idx = -1


func _on_entry_text_submitted(p_command: String) -> void:
	_clear_autocomplete()
	_fill_entry("")
	execute_command(p_command)
	_update_autocomplete()


func _on_entry_text_changed() -> void:
	_clear_autocomplete()
	_update_autocomplete()
