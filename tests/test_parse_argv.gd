extends SceneTree
## Tests for argument parsing when executing commands.
## Requires LimboConsole to be enabled as an autoload in the project.
## Run: godot --headless -s res://addons/limbo_console/tests/test_parse_argv.gd

var _result: Array
var _failed: int = 0
var _total: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var console: Node = root.get_node("LimboConsole")

	console.register_command(_one_string, "t_one_string")
	_check(console, "t_one_string", ["a_def"])
	_check(console, "t_one_string hello world", ["hello world"])
	_check(console, "t_one_string \"quoted text\"", ["quoted text"])

	console.register_command(_two_strings.bind("BOUND"), "t_two_bound")
	_check(console, "t_two_bound", ["", "BOUND"])
	_check(console, "t_two_bound hello world", ["hello world", "BOUND"])

	print("%d/%d passed" % [_total - _failed, _total])
	quit(1 if _failed > 0 else 0)


func _check(p_console: Node, p_command_line: String, p_expected: Array) -> void:
	_total += 1
	_result = []
	p_console.execute_command(p_command_line, true)
	if _result != p_expected:
		_failed += 1
		printerr("FAIL: '%s' -> %s, expected %s" % [p_command_line, _result, p_expected])


func _one_string(p_a: String = "a_def") -> void:
	_result = [p_a]


func _two_strings(p_a: String = "a_def", p_b: String = "b_def") -> void:
	_result = [p_a, p_b]
