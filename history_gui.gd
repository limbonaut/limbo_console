extends Panel

var _last_highlighted_label : RichTextLabel
var _history_labels : Array[RichTextLabel] # 
var _vbox : VBoxContainer
var _scroll_container : ScrollContainer
var _command_history : Array
var _current_index = 0
var _command = "<placeholder>"
var _number_visible = 0

# Public
func set_visibility(p_visible):
	if not visible and p_visible:
		_current_index = _number_visible
		_update_highlight()
		_scroll_container.scroll_vertical = _scroll_container.get_v_scroll_bar().max_value
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
	# Note that the list is going upwards so indexing is backwards
	if _current_index + 1 > _number_visible:
		return
	_current_index += 1
	_update_highlight()

## Move cursor upwards
func increment_index():
	# Note that the list is going upwards so indexing is backwards
	if _current_index - 1 < 0:
		return
	_current_index -= 1
	_update_highlight()

## Get the current selected text
func get_current_text():
	var current_text = ""
	if _history_labels.size() != 0:
		current_text = _history_labels[_current_index].text
	return current_text

## Search for the command in the history
func search(command):
	# Don't process if we used the same command before
	if command == _command:
		return
	var filter_shorted = command.length() < _command.length()
	_command = command
		
	var results = _fuzzy_match(command, _command_history)
	if command.length() == 0:
		results = _command_history
	# Display sorted list of commands
	var added_commands = []
	var last_added_item = null
	var vbox_children_count = _vbox.get_child_count()
	for i in range(0, vbox_children_count):
		var child = _vbox.get_child(i)
		child.visible = false
		if i < results.size():
			child.visible = true
			_current_index = i
			child.text = results[i]
			_number_visible = i
		
	_update_highlight()

	_scroll_container.scroll_vertical = _scroll_container.get_v_scroll_bar().max_value

# Variables
const THEME_DEFAULT := "res://addons/limbo_console/res/default_theme.tres"

# Private Functions

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT) 
	_init_theme()
	_scroll_container = ScrollContainer.new()
	_scroll_container.anchor_left = 0.0   # Left edge at 0% of the parent
	_scroll_container.anchor_top = 0.0    # Top edge at 0% of the parent
	_scroll_container.anchor_right = 1.0  # Right edge at 100% of the parent
	_scroll_container.anchor_bottom = 1.0 # Bottom edge at 100% of the parent
	_scroll_container.follow_focus = true
	add_child(_scroll_container)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_vbox)
	
	for i in range(0, 1000):
		var new_item = RichTextLabel.new()
		new_item.size_flags_vertical = Control.SIZE_EXPAND_FILL
		new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_item.fit_content = true
		new_item.focus_mode = Control.FOCUS_ALL
		new_item.scroll_active = false
		_history_labels.append(new_item)
		_vbox.add_child(new_item)
	
func _update_highlight():
	if _current_index < 0 or _command_history.size() == 0:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#515d70")
	if is_instance_valid(_last_highlighted_label):
		_last_highlighted_label.remove_theme_stylebox_override("normal")
		
	_history_labels[_current_index].add_theme_stylebox_override("normal", style)
	_last_highlighted_label = _history_labels[_current_index]
	_history_labels[_current_index].grab_focus()

func _init_theme() -> void:
	var _loaded_theme: Theme
	_loaded_theme = load(THEME_DEFAULT).duplicate(true)

	const CONSOLE_COLORS_THEME_TYPE := &"HistoryColors"
	var _panel_background_color = _loaded_theme.get_color(&"panel_background", CONSOLE_COLORS_THEME_TYPE)
	var _value = _loaded_theme.get_stylebox("panel", "Panel").duplicate(true)
	_value.bg_color = _panel_background_color
	theme = _loaded_theme
	_loaded_theme.set_stylebox("panel", "Panel", _value)

# Fuzzy search function similar to fzf
static func _fuzzy_match(query: String, items: Array) -> Array:
	var results = []

	for item in items:
		var score = _compute_match_score(query.to_lower(), item.to_lower())
		if score > 0:
			results.append({"item": item, "score": score})

	# Sort results by highest score
	results.sort_custom(func(a, b): return a.score < b.score)

	return results.map(func(entry): return entry.item)

# Scoring function for fuzzy matching
static func _compute_match_score(query: String, target: String) -> int:
	var score = 0
	var query_index = 0

	for i in range(target.length()):
		if query_index < query.length() and target[i] == query[query_index]:
			score += 10  # Base score for a match
			if i == 0 or target[i - 1] == " ":  # Bonus for word start
				score += 5
			query_index += 1
			if query_index == query.length():
				break

	return score if query_index == query.length() else 0  # Ensure full query matches
