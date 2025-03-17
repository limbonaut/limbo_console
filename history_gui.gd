extends Panel

const Util := preload("res://addons/limbo_console/util.gd")
var history_items : Array
var history_lines : Array
var vbox : VBoxContainer
var scroll_container : ScrollContainer
var _command_history : Array
var _current_index = 0
var _filter = "<placeholder>"

# Public
func set_visibility(p_visible):
	if not visible and p_visible:
		_current_index = history_lines.size() - 1
		_update_highlight()
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	visible = p_visible

func set_command_history(commands : Array):
	_command_history = commands

func add_command(command):
	_command_history.append(command)
	
func decrement_index():
	# Note that the list is going upwards so indexing is backwards
	if _current_index + 1 >= history_lines.size():
		return
	_current_index += 1
	_update_highlight()

func increment_index():
	# Note that the list is going upwards so indexing is backwards
	if _current_index - 1 < 0:
		return
	_current_index -= 1
	_update_highlight()

func get_current_text():
	var current_text = ""
	if history_lines.size() != 0:
		current_text = history_lines[_current_index].text
	return current_text

func update(filter):
	# Don't process if we used the same filter before
	if filter == _filter:
		return
	_filter = filter
	
	# Clear out previous vbox
	for child in vbox.get_children():
		remove_child(child)
		child.free()
	
	# Clear out references to deleted labels
	history_lines.clear()
	
	var results = _fuzzy_match(filter, _command_history)
	if filter.length() == 0:
		results = _command_history
	# Display sorted list of commands
	var added_commands = []
	var last_added_item = null
	for sorted_item in results:
		# Don't allow duplicate commands
		if sorted_item in added_commands:
			continue
		var new_item = Label.new()
		new_item.size_flags_vertical = Control.SIZE_EXPAND_FILL
		new_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#new_item.bbcode_enabled = true
		new_item.text = sorted_item
		history_lines.append(new_item)
		vbox.add_child(new_item)
		last_added_item = new_item
		vbox.visible = true
		added_commands.append(sorted_item)
	
	_current_index = history_lines.size() - 1
	_update_highlight()

	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

# Variables
const THEME_DEFAULT := "res://addons/limbo_console/res/default_theme.tres"

# Private Functions

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT) 
	_init_theme()
	scroll_container = ScrollContainer.new()
	scroll_container.anchor_left = 0.0   # Left edge at 0% of the parent
	scroll_container.anchor_top = 0.0    # Top edge at 0% of the parent
	scroll_container.anchor_right = 1.0  # Right edge at 100% of the parent
	scroll_container.anchor_bottom = 1.0 # Bottom edge at 100% of the parent
	add_child(scroll_container)
	
	vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	scroll_container.add_child(vbox)
	
func _update_highlight():
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#515d70")
	for i in range(0, history_lines.size()):
		if i == _current_index:
			history_lines[i].add_theme_stylebox_override("normal", style)
		else:
			history_lines[i].remove_theme_stylebox_override("normal")

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
				score += 10
			query_index += 1
			if query_index == query.length():
				break

	return score if query_index == query.length() else 0  # Ensure full query matches
