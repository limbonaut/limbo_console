extends TextEdit
## CommandEntry


signal text_submitted(command_line: String)


func _init() -> void:
	syntax_highlighter = CommandEntryHighlighter.new()


func _ready() -> void:
	caret_multiple = false

	# Determine minimum size.
	var font := get_theme_font("font", "TextEdit")
	var font_size = get_theme_font_size("font_size")
	var vsize: float = font.get_string_size("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 0, -1, font_size).y
	var sb := get_theme_stylebox("focus")
	vsize += sb.get_minimum_size().y
	custom_minimum_size = Vector2(0.0, vsize)

	get_v_scroll_bar().visibility_changed.connect(_hide_scrollbars)
	get_h_scroll_bar().visibility_changed.connect(_hide_scrollbars)
	_hide_scrollbars()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_FOCUS_ENTER:
			set_process_input(true)
		NOTIFICATION_FOCUS_EXIT:
			set_process_input(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ENTER:
			if event.is_pressed():
				submit_text()
			get_viewport().set_input_as_handled()


func submit_text() -> void:
	text_submitted.emit(text)
	clear()


func _hide_scrollbars() -> void:
	get_v_scroll_bar().hide()
	get_h_scroll_bar().hide()


class CommandEntryHighlighter extends SyntaxHighlighter:
	var command_found_color: Color
	var command_not_found_color: Color
	var text_color: Color

	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var command_color: Color
		var command_name: String
		var text: String = get_text_edit().text
		var end: int = 0

		for c in text:
			if c == ' ':
				break
			end += 1
		command_name = text.substr(0, end).strip_edges()
		command_color = command_found_color if LimboConsole.has_command(command_name) else command_not_found_color

		return {
			0: {"color": command_color},
			end: {"color": text_color},
			}
