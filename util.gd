extends Object
## Utility functions


static func bbcode_escape(p_text: String) -> String:
	return p_text \
		.replace("[", "~LB~") \
		.replace("]", "~RB~") \
		.replace("~LB~", "[lb]") \
		.replace("~RB~", "[rb]")


static func bbcode_strip(p_text: String) -> String:
	var stripped := ""
	var in_brackets: bool = false
	for c: String in p_text:
		if c == '[':
			in_brackets = true
		elif c == ']':
			in_brackets = false
		elif not in_brackets:
			stripped += c
	return stripped


static func get_method_info(p_callable: Callable) -> Dictionary:
	var method_info: Dictionary
	var method_list: Array[Dictionary]
	if p_callable.get_object() is GDScript:
		method_list = p_callable.get_object().get_script_method_list()
	else:
		method_list = p_callable.get_object().get_method_list()
	for m in method_list:
		if m.name == p_callable.get_method():
			method_info = m
			break
	if !method_info and p_callable.is_custom():
		var args: Array
		var default_args: Array
		for i in p_callable.get_argument_count():
			var argument: Dictionary
			argument["name"] = "arg%d" % i
			argument["type"] = TYPE_NIL
			args.push_back(argument)
		method_info["name"] = "<anonymous lambda>"
		method_info["args"] = args
		method_info["default_args"] = default_args
	return method_info


## Finds the most similar string in an array.
static func fuzzy_match_string(p_string: String, p_max_edit_distance: int, p_array) -> String:
	if typeof(p_array) < TYPE_ARRAY:
		push_error("LimboConsole: Internal error: p_array is not an array")
		return ""
	if p_array.size() == 0:
		return ""
	var best_distance: int = 9223372036854775807
	var best_match: String = ""
	for i in p_array.size():
		var elem := str(p_array[i])
		var dist: float = _calculate_osa_distance(p_string, elem)
		if dist < best_distance:
			best_distance = dist
			best_match = elem
	return best_match if best_distance <= p_max_edit_distance else ""


## Calculates optimal string alignment distance [br]
## See: https://en.wikipedia.org/wiki/Levenshtein_distance
static func _calculate_osa_distance(s1: String, s2: String) -> int:
	var s1_len: int = s1.length()
	var s2_len: int = s2.length()

	# Iterative approach with 3 matrix rows.
	# Most of the work is done on row1 and row2 - row0 is only needed to calculate transposition cost.
	var row0: PackedInt32Array # previous-previous
	var row1: PackedInt32Array # previous
	var row2: PackedInt32Array # current aka the one we need to calculate
	row0.resize(s2_len + 1)
	row1.resize(s2_len + 1)
	row2.resize(s2_len + 1)

	# edit distance is the number of characters to insert to get from empty string to s2
	for i in range(s2_len + 1):
		row1[i] = i

	for i in range(s1_len):
		# edit distance is the number of characters to delete from s1 to match empty s2
		row2[0] = i + 1

		for j in range(s2_len):
			var deletion_cost: int = row1[j + 1] + 1
			var insertion_cost: int = row2[j] + 1
			var substitution_cost: int = row1[j] if s1[i] == s2[j] else row1[j] + 1

			row2[j + 1] = min(deletion_cost, insertion_cost, substitution_cost)

			if i > 1 and j > 1 and s1[i - 1] == s2[j] and s1[i - 1] == s2[j]:
				var transposition_cost: int = row0[j - 1] + 1
				row2[j + 1] = mini(transposition_cost, row2[j + 1])

		# Swap rows.
		var tmp: PackedInt32Array = row0
		row0 = row1
		row1 = row2
		row2 = tmp
	return row1[s2_len]


## Returns true, if a string is constructed of one or more space-separated valid
## command identifiers ("command" or "command sub1 sub2").
## A valid command identifier may contain only letters, digits, and underscores (_),
## and the first character may not be a digit.
static func is_valid_command_sequence(p_string: String) -> bool:
	for part in p_string.split(' '):
		if not part.is_valid_ascii_identifier():
			return false
	return true
