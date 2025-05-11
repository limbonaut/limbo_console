extends TextEdit
## CommandEntry


signal text_submitted(command_line: String)
signal autocomplete_requested()

var autocomplete_hint: String:
	set(value):
		if autocomplete_hint != value:
			autocomplete_hint = value
			queue_redraw()

var _font: Font
var _font_size: int
var _hint_color: Color
var _sb_normal: StyleBox

func _init() -> void:
	syntax_highlighter = CommandEntryHighlighter.new()


func _ready() -> void:
	caret_multiple = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	scroll_fit_content_height = true
	# placeholder_text = ""

	get_v_scroll_bar().visibility_changed.connect(_hide_scrollbars)
	get_h_scroll_bar().visibility_changed.connect(_hide_scrollbars)
	_hide_scrollbars()

	_font = get_theme_font("font")
	_font_size = get_theme_font_size("font_size")
	_hint_color = get_theme_color("hint_color")
	_sb_normal = get_theme_stylebox("normal")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_FOCUS_ENTER:
			set_process_input(true)
		NOTIFICATION_FOCUS_EXIT:
			set_process_input(false)


func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event is InputEventKey:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.is_pressed():
				submit_text()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C and event.get_modifiers_mask() == KEY_MASK_CTRL and get_selected_text().is_empty():
			# Clear input on Ctrl+C if no text selected.
			if event.is_pressed():
				text = ""
				text_changed.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_RIGHT, KEY_END] and get_caret_column() == text.length():
			# Request autocomplete on RIGHT & END.
			if event.is_pressed() and not autocomplete_hint.is_empty():
				autocomplete_requested.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var offset_x: int = 0
	offset_x += _sb_normal.get_offset().x * 0.5
	offset_x += get_line_width(0)

	var offset_y: int = 0
	offset_y += _sb_normal.get_offset().y * 0.5
	offset_y += get_line_height() + 0.5 # + line_spacing
	offset_y -= _font.get_descent(_font_size)

	draw_string(_font, Vector2(offset_x, offset_y), autocomplete_hint, 0, -1, _font_size, _hint_color)


func submit_text() -> void:
	text_submitted.emit(text)


func _hide_scrollbars() -> void:
	get_v_scroll_bar().hide()
	get_h_scroll_bar().hide()


class CommandEntryHighlighter extends SyntaxHighlighter:
	var command_found_color: Color
	var subcommand_color: Color
	var command_not_found_color: Color
	var text_color: Color

	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var text: String = get_text_edit().text
		var command_end_idx: int = -1 # index where last recognized command ends (with subcommands)

		var argv: PackedStringArray = [] # argument vector (aka tokens)
		var argi: PackedInt32Array = [] # argument starting indices in text
		var start: int = 0
		var cur: int = 0
		for char in text + ' ':
			if char == ' ':
				if cur > start:
					argv.append(text.substr(start, cur - start))
					argi.append(start)
					var maybe_command: String = ' '.join(argv)
					if LimboConsole.has_command(maybe_command) or LimboConsole.has_alias(maybe_command):
						command_end_idx = cur
				start = cur + 1
			cur += 1

		var command_color: Color
		var arg_start_idx: int = 0 # index where arguments start

		if command_end_idx > -1:
			command_color = command_found_color
			arg_start_idx = command_end_idx + 1
		else:
			command_color = command_not_found_color
			arg_start_idx = argi[1] if argi.size() > 1 else text.length()

		var result: Dictionary
		result[0] = { "color": command_color }
		if command_end_idx > -1 and argi.size() > 1:
			result[argi[1]] = { "color": subcommand_color }
		result[arg_start_idx] = { "color": text_color }
		return result
