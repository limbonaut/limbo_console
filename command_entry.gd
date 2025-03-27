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
	clear()


func _hide_scrollbars() -> void:
	get_v_scroll_bar().hide()
	get_h_scroll_bar().hide()


class CommandEntryHighlighter extends SyntaxHighlighter:
	var command_found_color: Color
	var command_not_found_color: Color
	var command_group_found_color: Color
	var alias_found_color: Color
	var text_color: Color

	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var color_dict: Dictionary = {}
		if get_text_edit().text.is_empty():
			return color_dict
		var command_chain = LimboConsole._parse_command_line(get_text_edit().text)
		# TODO: _ indicates private -- do we need to update this?
		var args_only: Array = LimboConsole._get_args_from_array(command_chain)
		var usage_key: Array = command_chain.slice(0, command_chain.size() - args_only.size())
		var text_start = 0
		var text_end = 0 if command_chain.size() > 0 else len(command_chain[0])
		var current_chain = PackedStringArray([])
		for item in usage_key:
			if item.is_empty():
				continue
			current_chain.append(item)
			var chain_as_string = " ".join(current_chain)
			# Aliases can override commands so it comes first for coloring
			if LimboConsole.has_alias(item):
				color_dict.set(text_start, {"color": alias_found_color})
			elif LimboConsole.has_command(chain_as_string):
				color_dict.set(text_start, {"color": command_found_color})
			elif LimboConsole.has_command_group(chain_as_string):
				color_dict.set(text_start, {"color": command_group_found_color})
			else:
				color_dict.set(text_start, {"color": command_not_found_color})
			text_end += len(item) + 1
			text_start = text_end
		# TODO: When aliases support arguments uncomment the below to
		# color coat the replacement with alias color
		#for item in args_only:
			#if LimboConsole.has_alias(item):
				#color_dict.set(text_start, {"color": alias_found_color})
			#else:
				#color_dict.set(text_start, {"color": text_color})
			#text_end += len(item) + 1
			#text_start = text_end
		color_dict.set(text_end, {"color": text_color})
		return color_dict
