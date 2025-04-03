extends Panel

const CommandHistory := preload("res://addons/limbo_console/command_history.gd")

# Visual Elements
var _last_highlighted_label: Label
var _history_labels: Array[Label]
var _scroll_bar: VScrollBar
var _scroll_bar_width: int = 12

# Indexing Results
var _command: String = "<placeholder>"  # Needs default value so first search always processes
var _history: CommandHistory  # Command history to search through
var _filter_results: PackedStringArray  # Most recent results of performing a search for the _command in _history

var _display_count: int = 0  # Number of history items to display in search
var _offset: int = 0  # The offset _filter_results
var _sub_index: int = 0  # The highlight index

# Theme Cache
var _highlight_color: Color


# *** GODOT / VIRTUAL


func _init(p_history: CommandHistory) -> void:
	_history = p_history

	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Create first label, and set placeholder text to determine the display size
	# once this node is _ready(). There should always be one label at minimum
	# anyways since this search is usless without a way to show results.
	var new_item := Label.new()
	new_item.size_flags_vertical = Control.SIZE_SHRINK_END
	new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_item.text = "<Placeholder>"
	add_child(new_item)
	_history_labels.append(new_item)

	_scroll_bar = VScrollBar.new()
	add_child(_scroll_bar)


func _ready() -> void:
	# The sizing of the labels is dependant on visiblity.
	visibility_changed.connect(_calculate_display_count)
	_scroll_bar.scrolling.connect(_scroll_bar_scrolled)

	_highlight_color = get_theme_color(&"history_highlight_color", &"ConsoleColors")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# Scroll up/down on mouse wheel up/down
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_increment_index()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_decrement_index()

	# Remaining inputs are key press handles
	if event is not InputEventKey:
		return

	# Increment/Decrement index
	if event.keycode == KEY_UP and event.is_pressed():
		_increment_index()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DOWN and event.is_pressed():
		_decrement_index()
		get_viewport().set_input_as_handled()


# *** PUBLIC


## Set visibility of history search
func set_visibility(p_visible: bool) -> void:
	if not visible and p_visible:
		# It's possible the _history has updated while not visible
		# make sure the filtered list is up-to-date
		_search_and_filter()
	visible = p_visible


## Move cursor downwards
func _decrement_index() -> void:
	var current_index: int = _get_current_index()
	if current_index - 1 < 0:
		return

	if _sub_index == 0:
		_offset -= 1
		_update_scroll_list()
	else:
		_sub_index -= 1
		_update_highlight()


## Move cursor upwards
func _increment_index() -> void:
	var current_index: int = _get_current_index()
	if current_index + 1 >= _filter_results.size():
		return

	if _sub_index >= _display_count - 1:
		_offset += 1
		_update_scroll_list()
	else:
		_sub_index += 1
		_update_highlight()


## Get the current selected text
func get_current_text() -> String:
	var current_text: String = _command
	if _history_labels.size() != 0 and _filter_results.size() != 0:
		current_text = _filter_results[_get_current_index()]
	return current_text


## Search for the command in the history
func search(command: String) -> void:
	# Don't process if we used the same command before
	if command == _command:
		return
	_command = command

	_search_and_filter()


# *** PRIVATE


## Update the text in the scroll list to match current offset and filtered results
func _update_scroll_list() -> void:
	# Iterate through the number of displayed history items
	for i in range(0, _display_count):
		var filter_index: int = _offset + i

		# Default empty
		_history_labels[i].text = ""

		# Set non empty if in range
		var index_in_range: bool = filter_index < _filter_results.size()
		if index_in_range:
			_history_labels[i].text += _filter_results[filter_index]

	_update_scroll_bar()


## Highlight the subindex
func _update_highlight() -> void:
	if _sub_index < 0 or _history.size() == 0:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = _highlight_color

	# Always clear out the highlight of the last label
	if is_instance_valid(_last_highlighted_label):
		_last_highlighted_label.remove_theme_stylebox_override("normal")

	if _filter_results.size() <= 0:
		return

	_history_labels[_sub_index].add_theme_stylebox_override("normal", style)
	_last_highlighted_label = _history_labels[_sub_index]


## Get the current index of the selected item
func _get_current_index() -> int:
	return _offset + _sub_index


## Reset offset and sub_indexes to scroll list back to bottom
func _reset_indexes() -> void:
	_offset = 0
	_sub_index = 0


## When the scrollbar has been scrolled (by mouse), scroll the list
func _scroll_bar_scrolled() -> void:
	_offset = _scroll_bar.max_value - _display_count - _scroll_bar.value
	_update_highlight()
	_update_scroll_list()


func _calculate_display_count():
	if not visible:
		return
	# The display count is finnicky to get right due to the label needing to be
	# rendered so the fize can be determined. This gets the job done, it ain't
	# pretty, but it works
	var max_y: float = size.y

	var label_size_y: float = (_history_labels[0] as Control).size.y
	var label_size_x: float = size.x - _scroll_bar_width

	var display_count: int = int(max_y) / int(label_size_y)
	if _display_count != display_count and display_count != 0 and display_count > _display_count:
		_display_count = (display_count as int)

	# Since the labels are going from the bottom to the top, the label
	# coordinates are offset from the bottom by label size.
	# The first label already exists, so it's handlded by itself
	_history_labels[0].position.y = size.y - label_size_y
	_history_labels[0].set_size(Vector2(label_size_x, label_size_y))
	# The remaining labels may or may not exist already, create them
	for i in range(0, _display_count - _history_labels.size()):
		var new_item := Label.new()
		new_item.size_flags_vertical = Control.SIZE_SHRINK_END
		new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# The +1 is due to the labels going upwards from the bottom, otherwise
		# their position will be 1 row lower than they should be
		var position_offset: int = _history_labels.size() + 1
		new_item.position.y = size.y - (position_offset * label_size_y)
		new_item.set_size(Vector2(label_size_x, label_size_y))
		_history_labels.append(new_item)
		add_child(new_item)

	# Update the scroll bar to be positioned correctly
	_scroll_bar.size.x = _scroll_bar_width
	_scroll_bar.size.y = size.y
	_scroll_bar.position.x = label_size_x

	_reset_history_to_beginning()


func _update_scroll_bar() -> void:
	if _display_count > 0:
		var max_size: int = _filter_results.size()
		_scroll_bar.max_value = max_size
		_scroll_bar.page = _display_count
		_scroll_bar.set_value_no_signal((max_size - _display_count) - _offset)


## Reset indexes to 0, scroll to the bottom of the history list, and update visuals
func _reset_history_to_beginning() -> void:
	_reset_indexes()
	_update_highlight()
	_update_scroll_list()


## Search for the current command and filter the results
func _search_and_filter() -> void:
	_filter_results = _history.fuzzy_match(_command)

	_reset_history_to_beginning()
