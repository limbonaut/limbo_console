extends Panel

################################################################################
# Variables
################################################################################

# Visual Elements
const THEME_DEFAULT := "res://addons/limbo_console/res/default_theme.tres"
var _last_highlighted_label: Label
var _history_labels: Array[Label]
var _scroll_bar: VScrollBar
var _scroll_bar_width = 12

# Indexing Results
var _command = "<placeholder>"  # Needs default value so first search always processes
var _command_history: Array  # Command history to search throgh
var _filter_results: Array  # Most recent results of performing a search for the _command in _command_history

var _display_count: int = 0  # Number of history items to display in search
var _offset: int = 0  # The offset _filter_results
var _sub_index: int = 0  # The highlight index

# Theme Colors [TODO: Flesh out theme colors]
var _highlight_color: Color

################################################################################
# Public Functions
################################################################################


## Set visibility of history search
func set_visibility(p_visible: bool):
	if not visible and p_visible:
		_offset = 0
		_reset_indexes()
		_update_highlight()
		_update_scroll_list()
	visible = p_visible


## Set the command history to search through
func set_command_history(commands: Array):
	_command_history = commands
	_update_highlight()


## Add a command to the history to search through
func add_command(command: String):
	_command_history.append(command)
	_update_highlight()


## Move cursor downwards
func _decrement_index():
	var current_index = _get_current_index()
	if current_index - 1 < 0:
		return

	if _sub_index == 0:
		_offset -= 1
		_update_scroll_list()
	else:
		_sub_index -= 1
		_update_highlight()


## Move cursor upwards
func _increment_index():
	var current_index = _get_current_index()
	if current_index + 1 >= _filter_results.size():
		return

	if _sub_index >= _display_count - 1:
		_offset += 1
		_update_scroll_list()
	else:
		_sub_index += 1
		_update_highlight()


## Get the current selected text
func get_current_text():
	var current_text = ""
	if _history_labels.size() != 0 and _filter_results.size() != 0:
		current_text = _filter_results[_get_current_index()]
	return current_text


## Search for the command in the history
func search(command):
	# Don't process if we used the same command before
	if command == _command:
		return
	_command = command

	# Empty string so show all results
	if _command.length() == 0:
		_filter_results = _command_history

		# Results are reversed since the list needs to go up instead of down
		_filter_results.reverse()
	else:
		_filter_results = _fuzzy_match(command, _command_history)

	_reset_indexes()
	_update_scroll_list()
	_update_highlight()


################################################################################
# Private Functions
################################################################################


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_init_theme()

	# Create first label, and set placeholder text to determine the display size
	# once this node is _ready(). There should always be one label at minimum
	# anyways since this search is usless without a way to show results.
	var new_item = Label.new()
	new_item.size_flags_vertical = Control.SIZE_SHRINK_END
	new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_item.text = "<Placeholder>"
	add_child(new_item)
	_history_labels.append(new_item)

	_scroll_bar = VScrollBar.new()
	add_child(_scroll_bar)


## Update the text in the scroll list to match current offset and filtered results
func _update_scroll_list():
	# Iterate through the number of displayed history items
	for i in range(0, _display_count):
		var filter_index = _offset + i

		# Default empty
		_history_labels[i].text = ""

		# Set non empty if in range
		var index_in_range = filter_index < _filter_results.size()
		if index_in_range:
			_history_labels[i].text += _filter_results[filter_index]

	_update_scroll_bar()


## Highlight the subindex
func _update_highlight():
	if _sub_index < 0 or _command_history.size() == 0:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = _highlight_color
	
	# Always clear out the highlight of the last label
	if is_instance_valid(_last_highlighted_label):
		_last_highlighted_label.remove_theme_stylebox_override("normal")

	if _filter_results.size() <= 0:
		return

	_history_labels[_sub_index].add_theme_stylebox_override("normal", style)
	_last_highlighted_label = _history_labels[_sub_index]


## Initialize the theme and color variables
func _init_theme() -> void:
	var _loaded_theme: Theme
	_loaded_theme = load(THEME_DEFAULT)

	_highlight_color = _loaded_theme.get_color(
		&"history_highlight_color", &"ConsoleColors"
	)


## Fuzzy search function similar to fzf
static func _fuzzy_match(query: String, items: Array) -> Array:
	var results = []

	for item in items:
		var score = _compute_match_score(query.to_lower(), item.to_lower())
		if score > 0:
			results.append({"item": item, "score": score})

	# Sort results by highest score
	results.sort_custom(func(a, b): return a.score > b.score)

	return results.map(func(entry): return entry.item)


## Scoring function for fuzzy matching
static func _compute_match_score(query: String, target: String) -> int:
	var score = 0
	var query_index = 0

	# Exact match. give unbeatable score
	if query == target:
		score = 99999
		return score

	for i in range(target.length()):
		if query_index < query.length() and target[i] == query[query_index]:
			score += 10  # Base score for a match
			if i == 0 or target[i - 1] == " ":  # Bonus for word start
				score += 5
			query_index += 1
			if query_index == query.length():
				break

	# Ensure full query matches
	return score if query_index == query.length() else 0


## Get the current index of the selected item
func _get_current_index():
	return _offset + _sub_index


## Reset offset and sub_indexes to scroll list back to bottom
func _reset_indexes():
	_offset = 0
	_sub_index = 0


func _ready():
	# The sizing of the labels is dependant on visiblity
	connect("visibility_changed", _calculate_display_count)
	_scroll_bar.connect("scrolling", _scroll_bar_scrolled)


## When the scrollbar has been scrolled (by mouse), scroll the list
func _scroll_bar_scrolled():
	_offset = _scroll_bar.max_value - _display_count - _scroll_bar.value
	_update_highlight()
	_update_scroll_list()


func _input(event):
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


func _calculate_display_count():
	if not visible:
		return
	# The display count is finnicky to get right due to the label needing to be
	# rendered so the fize can be determined. This gets the job done, it ain't
	# pretty, but it works
	var max_y = size.y

	var label_size_y = (_history_labels[0] as Control).size.y
	var label_size_x = size.x - _scroll_bar_width

	var display_count = max_y as int / label_size_y as int
	if _display_count != display_count and display_count != 0 and display_count > _display_count:
		_display_count = (display_count as int)

	# Since the labels are going from the bottom to the top, the label
	# coordinates are offset from the bottom by label size.
	# The first label already exists, so it's handlded by itself
	_history_labels[0].position.y = size.y - label_size_y
	_history_labels[0].set_size(Vector2(label_size_x, label_size_y))
	# The remaining labels may or may not exist already, create them 
	for i in range(0, _display_count - _history_labels.size()):
		var new_item = Label.new()
		new_item.size_flags_vertical = Control.SIZE_SHRINK_END
		new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# The +1 is due to the labels going upwards from the bottom, otherwise 
		# their position will be 1 row lower than they should be
		var position_offset = _history_labels.size() + 1
		new_item.position.y = size.y - (position_offset * label_size_y)
		new_item.set_size(Vector2(label_size_x, label_size_y))
		_history_labels.append(new_item)
		add_child(new_item)

	# Update the scroll bar to be positioned correctly
	_scroll_bar.size.x = _scroll_bar_width
	_scroll_bar.size.y = size.y
	_scroll_bar.position.x = label_size_x

	_reset_indexes()
	_update_highlight()
	_update_scroll_list()


func _update_scroll_bar():
	if (_filter_results.size() > 0) and (_display_count > 0):
		var max_size = _filter_results.size()
		_scroll_bar.max_value = max_size
		_scroll_bar.page = _display_count
		_scroll_bar.set_value_no_signal((max_size - _display_count) - _offset)
