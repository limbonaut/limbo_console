extends RefCounted
## BuiltinCommands


const Util := preload("res://addons/limbo_console/util.gd")


static func register_commands() -> void:
	LimboConsole.register_command(cmd_alias, "alias", "add command alias")
	LimboConsole.register_command(cmd_aliases, "aliases", "list all aliases")
	LimboConsole.register_command(LimboConsole.clear_console, "clear", "clear console screen")
	LimboConsole.register_command(cmd_commands, "commands", "list all commands")
	LimboConsole.register_command(LimboConsole.info, "echo", "display a line of text")
	LimboConsole.register_command(cmd_eval, "eval", "evaluate an expression")
	LimboConsole.register_command(cmd_exec, "exec", "execute commands from file")
	LimboConsole.register_command(cmd_fps_max, "fps_max", "limit framerate")
	LimboConsole.register_command(cmd_fullscreen, "fullscreen", "toggle fullscreen mode")
	LimboConsole.register_command(cmd_help, "help", "show command info")
	LimboConsole.register_command(cmd_log, "log", "show recent log entries")
	LimboConsole.register_command(cmd_quit, "quit", "exit the application")
	LimboConsole.register_command(cmd_unalias, "unalias", "remove command alias")
	LimboConsole.register_command(cmd_vsync, "vsync", "adjust V-Sync")
	LimboConsole.register_command(LimboConsole.erase_history, "erase_history", "erases current history and persisted history")
	LimboConsole.add_argument_autocomplete_source("help", 1, LimboConsole.get_command_names.bind(true))


static func cmd_alias(p_alias: String, p_command: String) -> void:
	LimboConsole.info("Adding %s => %s" % [LimboConsole.format_name(p_alias), p_command])
	LimboConsole.add_alias(p_alias, p_command)


static func cmd_aliases() -> void:
	var aliases: Array = LimboConsole.get_aliases()
	aliases.sort()
	for alias in aliases:
		var alias_argv: PackedStringArray = LimboConsole.get_alias_argv(alias)
		var cmd_name: String = alias_argv[0]
		var desc: String = LimboConsole.get_command_description(cmd_name)
		alias_argv[0] = LimboConsole.format_name(cmd_name)
		if desc.is_empty():
			LimboConsole.info(LimboConsole.format_name(alias))
		else:
			LimboConsole.info("%s is alias of: %s %s" % [
				LimboConsole.format_name(alias),
				' '.join(alias_argv),
				LimboConsole.format_tip(" // " + desc)
			])


static func cmd_commands() -> void:
	LimboConsole.info("Available commands:")
	for name in LimboConsole.get_command_names(false):
		var desc: String = LimboConsole.get_command_description(name)
		name = LimboConsole.format_name(name)
		LimboConsole.info(name if desc.is_empty() else "%s -- %s" % [name, desc])


static func cmd_eval(p_expression: String) -> Error:
	var exp := Expression.new()
	var err: int = exp.parse(p_expression, LimboConsole.get_eval_input_names())
	if err != OK:
		LimboConsole.error(exp.get_error_text())
		return err
	var result = exp.execute(LimboConsole.get_eval_inputs(),
		LimboConsole.get_eval_base_instance())
	if not exp.has_execute_failed():
		if result != null:
			LimboConsole.info(str(result))
		return OK
	else:
		LimboConsole.error(exp.get_error_text())
		return ERR_SCRIPT_FAILED


static func cmd_exec(p_file: String, p_silent: bool = true) -> void:
	if not p_file.ends_with(".lcs"):
		# Prevent users from reading other game assets.
		p_file += ".lcs"
	if not FileAccess.file_exists(p_file):
		p_file = "user://" + p_file
	LimboConsole.execute_script(p_file, p_silent)


static func cmd_fps_max(p_limit: int = -1) -> void:
	if p_limit < 0:
		if Engine.max_fps == 0:
			LimboConsole.info("Framerate is unlimited.")
		else:
			LimboConsole.info("Framerate is limited to %d FPS." % [Engine.max_fps])
		return

	Engine.max_fps = p_limit
	if p_limit > 0:
		LimboConsole.info("Limiting framerate to %d FPS." % [p_limit])
	elif p_limit == 0:
		LimboConsole.info("Removing framerate limits.")


static func cmd_fullscreen() -> void:
	if LimboConsole.get_viewport().mode == Window.MODE_WINDOWED:
		# get_viewport().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		LimboConsole.get_viewport().mode = Window.MODE_FULLSCREEN
		LimboConsole.info("Window switched to fullscreen mode.")
	else:
		LimboConsole.get_viewport().mode = Window.MODE_WINDOWED
		LimboConsole.info("Window switched to windowed mode.")


static func cmd_help(p_command_name: String = "") -> Error:
	if p_command_name.is_empty():
		LimboConsole.print_line(LimboConsole.format_tip("Type %s to list all available commands." %
				[LimboConsole.format_name("commands")]))
		LimboConsole.print_line(LimboConsole.format_tip("Type %s to get more info about the command." %
				[LimboConsole.format_name("help command")]))
		return OK
	else:
		return LimboConsole.usage(p_command_name)


static func cmd_log(p_num_lines: int = 10) -> Error:
	var fn: String = ProjectSettings.get_setting("debug/file_logging/log_path")
	var file = FileAccess.open(fn, FileAccess.READ)
	if not file:
		LimboConsole.error("Can't open file: " + fn)
		return ERR_CANT_OPEN
	var contents := file.get_as_text()
	var lines := contents.split('\n')
	if lines.size() and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	lines = lines.slice(maxi(lines.size() - p_num_lines, 0))
	for line in lines:
		LimboConsole.print_line(Util.bbcode_escape(line), false)
	return OK


static func cmd_quit() -> void:
	LimboConsole.get_tree().quit()


static func cmd_unalias(p_alias: String) -> void:
	if LimboConsole.has_alias(p_alias):
		LimboConsole.remove_alias(p_alias)
		LimboConsole.info("Alias removed.")
	else:
		LimboConsole.warn("Alias not found.")


static func cmd_vsync(p_mode: int = -1) -> void:
	if p_mode < 0:
		var current: int = DisplayServer.window_get_vsync_mode()
		if current == 0:
			LimboConsole.info("V-Sync: disabled.")
		elif current == 1:
			LimboConsole.info('V-Sync: enabled.')
		elif current == 2:
			LimboConsole.info('Current V-Sync mode: adaptive.')
		LimboConsole.info("Adjust V-Sync mode with an argument: 0 - disabled, 1 - enabled, 2 - adaptive.")
	elif p_mode == DisplayServer.VSYNC_DISABLED:
		LimboConsole.info("Changing to disabled.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	elif p_mode == DisplayServer.VSYNC_ENABLED:
		LimboConsole.info("Changing to default V-Sync.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	elif p_mode == DisplayServer.VSYNC_ADAPTIVE:
		LimboConsole.info("Changing to adaptive V-Sync.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	else:
		LimboConsole.error("Invalid mode.")
		LimboConsole.info("Acceptable modes: 0 - disabled, 1 - enabled, 2 - adaptive.")
