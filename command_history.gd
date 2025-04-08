extends RefCounted
## Manages command history.


const HISTORY_FILE := "user://limbo_console_history.log"


var _entries: PackedStringArray
var _hist_idx = -1
var _iterators: Array[WrappingIterator]
var _is_dirty: bool = false


func push_entry(p_entry: String) -> void:
	_push_entry(p_entry)
	_reset_iterators()


func _push_entry(p_entry: String) -> void:
	var idx: int = _entries.find(p_entry)
	if idx != -1:
		# Duplicate commands not allowed in history.
		_entries.remove_at(idx)
	_entries.append(p_entry)
	_is_dirty = true


func get_entry(p_index: int) -> String:
	return _entries[clampi(p_index, 0, _entries.size())]


func create_iterator() -> WrappingIterator:
	var it := WrappingIterator.new(_entries)
	_iterators.append(it)
	return it


func release_iterator(p_iter: WrappingIterator) -> void:
	_iterators.erase(p_iter)


func size() -> int:
	return _entries.size()


func trim(p_max_size: int) -> void:
	if _entries.size() > p_max_size:
		_entries.slice(p_max_size - _entries.size())
	_reset_iterators()


func clear() -> void:
	_entries.clear()


func load(p_path: String = HISTORY_FILE) -> void:
	var file := FileAccess.open(p_path, FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			_push_entry(line)
	file.close()
	_reset_iterators()
	_is_dirty = false


func save(p_path: String = HISTORY_FILE) -> void:
	if not _is_dirty:
		return
	var file := FileAccess.open(p_path, FileAccess.WRITE)
	if not file:
		push_error("LimboConsole: Failed to save console history to file: ", p_path)
		return
	for line in _entries:
		file.store_line(line)
	file.close()
	_is_dirty = false


## Searches history and returns an array starting with most relevant entries.
func fuzzy_match(p_query: String) -> PackedStringArray:
	if len(p_query) == 0:
		var copy := _entries.duplicate()
		copy.reverse()
		return copy

	var results: Array = []
	for entry: String in _entries:
		var score: int = _compute_match_score(p_query.to_lower(), entry.to_lower())
		if score > 0:
			results.append({"entry": entry, "score": score})

	results.sort_custom(func(a, b): return a.score > b.score)
	return results.map(func(rec): return rec.entry)


func _reset_iterators() -> void:
	for it in _iterators:
		it._reassign(_entries)


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
	var _entries: PackedStringArray


	func _init(p_entries: PackedStringArray) -> void:
		_entries = p_entries


	func prev() -> String:
		_idx = wrapi(_idx - 1, -1, _entries.size())
		if _idx == -1:
			return String()
		return _entries[_idx]


	func next() -> String:
		_idx = wrapi(_idx + 1, -1, _entries.size())
		if _idx == -1:
			return String()
		return _entries[_idx]


	func current() -> String:
		if _idx < 0 or _idx >= _entries.size():
			return String()
		return _entries[_idx]


	func reset() -> void:
		_idx = -1


	func _reassign(p_entries: PackedStringArray) -> void:
		_idx = -1
		_entries = p_entries
