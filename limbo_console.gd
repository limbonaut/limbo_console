extends CanvasLayer
## LimboConsole

signal toggled(is_shown)

const FONT_NORMAL := preload("res://addons/limbo_console/res/monaspace_argon_regular.otf")
const FONT_BOLD := preload("res://addons/limbo_console/res/monaspace_argon_bold.otf")
const FONT_ITALIC := preload("res://addons/limbo_console/res/monaspace_argon_italic.otf")
const FONT_BOLD_ITALIC := preload("res://addons/limbo_console/res/monaspace_argon_bold_italic.otf")
const FONT_MONO := preload("res://addons/limbo_console/res/monaspace_argon_medium.otf")

var _console_control: Control
var _content: RichTextLabel
var _command_line: LineEdit

var _commands: Dictionary
var _command_aliases: Dictionary
var _command_descriptions: Dictionary
var _history: PackedStringArray
var _hist_idx: int = -1
var _autocomplete_matches: PackedStringArray


func _init() -> void:
	layer = 9999
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

	_build_gui()

	_console_control.hide()

	_command_line.text_submitted.connect(_on_command_line_submitted)
	_command_line.text_changed.connect(_on_command_line_changed)

	info("[b]" + ProjectSettings.get_setting("application/config/name") + " console[/b]")
	_cmd_help()
	info("[color=gray]-----[/color]")

	register_command(info, "echo", "display a line of text")
	register_command(_cmd_aliases, "aliases", "list all aliases")
	register_command(_cmd_commands, "commands", "list all commands")
	register_command(_cmd_help, "help", "show command info")
	register_command(clear_console, "clear", "clear console screen")
	register_command(_cmd_fullscreen, "fullscreen", "toggle fullscreen mode")
	register_command(_cmd_quit, "quit", "exit the application")

	add_alias("usage", "help")
	add_alias("exit", "quit")


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("limbo_console_toggle"):
		toggle_console()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed():
		var handled := true
		if event.keycode == KEY_UP:
			_hist_idx += 1
			_fill_from_history()
		elif event.keycode == KEY_DOWN:
			_hist_idx -= 1
			_fill_from_history()
		elif event.keycode == KEY_TAB:
			_autocomplete()
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
	_content.add_theme_font_override("normal_font", FONT_NORMAL)
	_content.add_theme_font_override("bold_font", FONT_BOLD)
	_content.add_theme_font_override("italics_font", FONT_ITALIC)
	_content.add_theme_font_override("bold_italics_font", FONT_BOLD_ITALIC)
	_content.add_theme_font_override("mono_font", FONT_MONO)
	vbox.add_child(_content)

	_command_line = LineEdit.new()
	vbox.add_child(_command_line)


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


func clear_console() -> void:
	_content.text = ""


func info(p_line: String) -> void:
	print_line(p_line)


func error(p_line: String) -> void:
	print_line("[b][color=red]ERROR:[/color][/b] " + p_line)


func warn(p_line: String) -> void:
	print_line("[color=yellow]WARNING:[/color] " + p_line)


func debug(p_line: String) -> void:
	print_line("[color=gray]DEBUG: " + p_line + "[/color]")


func print_line(p_line: String) -> void:
	var line: String = p_line + "\n"
	_content.text += line
	print_rich(line.strip_edges())


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


func is_command_registered(p_name: String) -> bool:
	return _commands.has(p_name) or _command_aliases.has(p_name)


func add_alias(p_alias: String, p_existing: String) -> void:
	if is_command_registered(p_alias):
		error("Command or alias already registered: " + p_alias)
		return
	if not is_command_registered(p_existing):
		error("Command not found: " + p_existing)
		return
	_command_aliases[p_alias] = p_existing


func remove_alias(p_alias: String) -> void:
	_command_aliases.erase(p_alias)


func execute_command(p_command_line: String, p_silent: bool = false) -> void:
	p_command_line = p_command_line.strip_edges()
	if p_command_line.is_empty():
		return

	var argv: PackedStringArray = _parse_command_line(p_command_line)
	var command_name: String = argv[0]
	var command_args: Array = []

	_push_history(" ".join(argv))
	if not p_silent:
		info("[color=green][b]>[/b] " + command_name + "[/color] " + " ".join(argv.slice(1, argv.size())))

	if not is_command_registered(command_name):
		error("Unknown command: " + command_name)
		return

	var dealiased_name: String = _command_aliases.get(command_name, command_name)

	var cmd: Callable = _commands.get(dealiased_name)
	var valid: bool = _parse_argv(argv, cmd, command_args)
	if valid:
		cmd.callv(command_args)
	else:
		_usage(command_name)


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


## Returns true if valid, also returns r_args array with converted arguments.
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


func _are_compatible_types(p_expected_type: int, p_parsed_type: int) -> bool:
	return p_expected_type == p_parsed_type or \
		p_expected_type == TYPE_NIL or \
		p_expected_type == TYPE_STRING or \
		p_expected_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and p_parsed_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]


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


func _usage(p_command_name: String) -> void:
	var dealiased_name: String = _command_aliases.get(p_command_name, p_command_name)
	if dealiased_name != p_command_name:
		info("Alias of " + _format_name(dealiased_name) + ".")
	var usage_line: String = "Usage: %s" % [dealiased_name]
	var arg_lines: String = ""
	var desc: String = ""
	var callable: Callable = _commands[dealiased_name]
	var method_info: Dictionary = _get_method_info(callable)
	if method_info.is_empty():
		error("Couldn't find method info for: " + callable.get_method())
		print_line("Usage: ???")
		return
	var required_args: int = method_info.args.size() - method_info.default_args.size()
	for i in range(method_info.args.size()):
		var arg_name: String = method_info.args[i].name.trim_prefix("p_")
		if i < required_args:
			usage_line += " " + arg_name
		else:
			usage_line += " [lb]" + arg_name + "[rb]"
		arg_lines += "\t%s: %s\n" % [arg_name, type_string(method_info.args[i].type)]
	print_line(usage_line)
	desc = _command_descriptions.get(dealiased_name, "")
	if not desc.is_empty():
		desc[0] = desc[0].capitalize()
		if desc.right(1) != ".":
			desc += "."
		print_line(desc)
	if not arg_lines.is_empty():
		print_line("Arguments:")
		print_line(arg_lines)


func _fill_command_line(p_line: String) -> void:
	_command_line.text = p_line
	_command_line.set_deferred(&"caret_column", p_line.length())

func _fill_from_history() -> void:
	_hist_idx = clampi(_hist_idx, -1, _history.size() - 1)
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


func _on_command_line_submitted(p_command: String) -> void:
	execute_command(p_command)
	_fill_command_line("")
	_autocomplete_matches.clear()


func _on_command_line_changed(p_line: String) -> void:
	_autocomplete_matches.clear()


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
		print_line("Type %s to list all available commands." % [_format_name("commands")])
		print_line("Type %s to get more info about the command." % [_format_name("help command")])
	elif is_command_registered(p_command_name):
		_usage(p_command_name)
	else:
		error("Command not found: " + _format_name(p_command_name))


func _cmd_quit() -> void:
	get_tree().quit()


func _format_name(p_name: String) -> String:
	return "[color=cyan]" + p_name + "[/color]"
