extends Panel

################################################################################
# Variables
################################################################################

# Visual Elements
const THEME_DEFAULT := "res://addons/limbo_console/res/default_theme.tres"
var _last_highlighted_label : Label
var _history_labels 		: Array[Label]

# Indexing Results
var _command = "<placeholder>" # Needs default value so first search always processes
var _command_history : Array # Command history to search throgh
var _filter_results  : Array # Most recent results of performing a search for the _command in _command_history

var _display_count = 0 # Number of history items to display in search [TODO: Make dynamic based on panel available space]
var _offset        = 0 # The offset _filter_results
var _sub_index     = 0 # The highlight index 
var _largest_y     = 0 # Largest y_size for a history item

# Theme Colors [TODO: Flesh out theme colors]
var _highlight_color : Color

################################################################################
# Public Functions
################################################################################

## Set visibility of history search
func set_visibility(p_visible):
	if not visible and p_visible:
		_offset = 0
		_reset_indexes()
		_update_highlight()
		_update_scroll_list()
	visible = p_visible

## Set the command history to search through
func set_command_history(commands : Array):
	_command_history = commands
	_update_highlight()

## Add a command to the history to search through
func add_command(command):
	_command_history.append(command)
	_update_highlight()

## Move cursor downwards
func decrement_index():
	var current_index = _offset + _sub_index
	# Note that the list is going upwards so indexing is backwards
	if current_index - 1 < 0:
		return

	if _sub_index == 0:
		_offset -= 1
		_update_scroll_list()
	else:
		_sub_index -= 1
		_update_highlight()

## Move cursor upwards
func increment_index():
	var current_index = _offset + _sub_index
	# Note that the list is going upwards so indexing is backwards
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
	var filter_shorted = command.length() < _command.length()
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
	
	
	# Create first label, this is gets set to placeholder text to determine
	# the display size once this node is _ready()
	var new_item = Label.new()
	new_item.size_flags_vertical = Control.SIZE_SHRINK_END
	new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_item.text = "<Placeholder>"
	add_child(new_item)
	_history_labels.append(new_item)

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

## Highlight the subindex
func _update_highlight():
	if _sub_index < 0 or _command_history.size() == 0:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = _highlight_color
	if is_instance_valid(_last_highlighted_label):
		_last_highlighted_label.remove_theme_stylebox_override("normal")

	if _filter_results.size() <= 0:
		return
		
	var highlight_index = _sub_index
	_history_labels[highlight_index].add_theme_stylebox_override("normal", style)
	_last_highlighted_label = _history_labels[highlight_index]

## Initialize the theme and color variables
func _init_theme() -> void:
	var _loaded_theme: Theme
	_loaded_theme = load(THEME_DEFAULT)

	const CONSOLE_COLORS_THEME_TYPE := &"ConsoleColors"
	_highlight_color = _loaded_theme.get_color(&"history_highlight_color", CONSOLE_COLORS_THEME_TYPE)

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
	connect("visibility_changed", _calculate_display_count)
	
func _calculate_display_count():
	# The display count is finnicky to get right due to the label needing to be
	# rendered so the fize can be determined. This gets the job done, it ain't 
	# pretty, but it works
	var max_y = size.y
	_history_labels[0].queue_redraw()
	
	var label_size_y = (_history_labels[0] as Control).size.y
	var label_size_x = size.x
	if label_size_y <= _largest_y:
		return
	_largest_y = label_size_y
	var display_count = (max_y as int / label_size_y as int)
	
	if _display_count != display_count and display_count != 0 and display_count > _display_count:
		_display_count = (display_count as int)
	
	for i in range(0, _display_count -_history_labels.size()):
		var new_item = Label.new()
		new_item.size_flags_vertical = Control.SIZE_SHRINK_END
		new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_item.position.y = size.y - (i + 2) * label_size_y
		new_item.set_size(Vector2(label_size_x, label_size_y))
		_history_labels.append(new_item)
		add_child(new_item)
	_history_labels[0].position.y = size.y - label_size_y
	_history_labels[0].set_size(Vector2(label_size_x, label_size_y))
	
	_reset_indexes()
	_update_highlight()
	_update_scroll_list()
