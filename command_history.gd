extends RefCounted

const HISTORY_FILE := "user://limbo_console_history.log"


var _history: PackedStringArray
var _hist_idx = -1
var _iterators: Array[WrappingIterator]


func push_command(p_command: String) -> void:
	_push_command(p_command)
	_reset_iterators()


func _push_command(p_command: String) -> void:
	var idx: int = _history.find(p_command)
	if idx != -1:
		# Duplicate commands not allowed in history.
		_history.remove_at(idx)
	_history.append(p_command)


func get_command(p_index: int) -> String:
	return _history[clampi(p_index, 0, _history.size())]


func create_iterator() -> WrappingIterator:
	var it := WrappingIterator.new(_history)
	_iterators.append(it)
	return it


func release_iterator(p_iter: WrappingIterator) -> void:
	_iterators.erase(p_iter)


func size() -> int:
	return _history.size()


func trim(p_max_size: int) -> void:
	if _history.size() > p_max_size:
		_history.slice(p_max_size - _history.size())
	_reset_iterators()


func clear() -> void:
	_history.clear()


func load(p_path: String = HISTORY_FILE) -> void:
	var file := FileAccess.open(p_path, FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			_push_command(line)
	file.close()
	_reset_iterators()


func save(p_path: String = HISTORY_FILE) -> void:
	var file := FileAccess.open(p_path, FileAccess.WRITE)
	if not file:
		push_error("LimboConsole: Failed to save console history to file: ", p_path)
		return
	for line in _history:
		file.store_line(line)
	file.close()


## Searches history and returns an array starting with most relevant entries.
func fuzzy_match(p_query: String) -> PackedStringArray:
	if len(p_query) == 0:
		var copy := _history.duplicate()
		copy.reverse()
		return copy

	var results: Array = []
	for cmd: String in _history:
		var score: int = _compute_match_score(p_query.to_lower(), cmd.to_lower())
		if score > 0:
			results.append({"command": cmd, "score": score})

	results.sort_custom(func(a, b): return a.score > b.score)
	return results.map(func(entry): return entry.command)


func _reset_iterators() -> void:
	for it in _iterators:
		it._reassign(_history)


## Scoring function for fuzzy matching.
static func _compute_match_score(query: String, target: String) -> int:
	var score: int = 0
	var query_index: int = 0

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


## Iterator that wraps around and resets on history change.
class WrappingIterator:
	extends RefCounted

	var _idx: int = -1
	var _commands: PackedStringArray


	func _init(p_commands: PackedStringArray) -> void:
		_commands = p_commands


	func prev() -> String:
		_idx = wrapi(_idx - 1, -1, _commands.size())
		if _idx == -1:
			return String()
		return _commands[_idx]


	func next() -> String:
		_idx = wrapi(_idx + 1, -1, _commands.size())
		if _idx == -1:
			return String()
		return _commands[_idx]


	func current() -> String:
		if _idx < 0 or _idx >= _commands.size():
			return String()
		return _commands[_idx]


	func reset() -> void:
		_idx = -1


	func _reassign(p_history: PackedStringArray) -> void:
		_idx = -1
		_commands = p_history
