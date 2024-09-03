extends RefCounted


const boxed_map: Dictionary = {
'a': """
▒▄▀█
░█▀█
""",
'b': """
░█▄▄
▒█▄█
""",
'c': """
░▄▀▀
░▀▄▄
""",
'd': """
▒█▀▄
░█▄▀
""",
'e': """
░██▀
▒█▄▄
""",
'f': """
░█▀▀
░█▀░
""",
'g': """
▒▄▀▀
░▀▄█
""",
'h': """
░█▄█
▒█▒█
""",
'i': """
░█
░█
""",
'j': """
░░▒█
░▀▄█
""",
'k': """
░█▄▀
░█▒█
""",
'l': """
░█▒░
▒█▄▄
""",
'm': """
▒█▀▄▀█
░█▒▀▒█
""",
'n': """
░█▄░█
░█▒▀█
""",
'o': """
░█▀█
▒█▄█
""",
'p': """
▒█▀█
░█▀▀
""",
'q': """
░▄▀▄
░▀▄█
""",
'r': """
▒█▀█
░█▀▄
""",
's': """
░▄▀
▒▄█
""",
't': """
░▀█▀
░▒█▒
""",
'u': """
░█░█
▒█▄█
""",
'v': """
░█░█
▒▀▄▀
""",
'w': """
▒█░█░█
░▀▄▀▄▀
""",
'x': """
░▀▄▀
░█▒█
""",
'y': """
░▀▄▀
░▒█▒
""",
'z': """
░▀█
▒█▄
""",
' ': """
░
░
""",
'_': """
░░░
▒▄▄
""",
',': """
░▒
░█
""",
'.': """
░░
░▄
""",
'!': """
░█
░▄
""",
'-': """
░▒░
░▀▀
""",
'?': """
░▀▀▄
░▒█▀
""",
'\'': """
░▀
░░
""",
':': """
░▄░
▒▄▒
""",
'0': """
░▄▀▄
░▀▄▀
""",
'1': """
░▄█
░░█
""",
'2': """
░▀█
░█▄
""",
'3': """
░▀██
░▄▄█
""",
'4': """
░█▄
░░█
""",
'5': """
░█▀
░▄█
""",
'6': """
░█▀
░██
""",
'7': """
░▀█
░█░
""",
'8': """
░█▄█
░█▄█
""",
'9': """
░██
░▄█
""",
}

const unsupported_char := """
░▒░
▒░▒
"""


static func str_to_boxed_art(p_text: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.resize(2)
	for c in p_text:
		var ascii: String = boxed_map.get(c.to_lower(), unsupported_char)
		var parts: PackedStringArray = ascii.split('\n')
		lines[0] += parts[1]
		lines[1] += parts[2]
	return lines


static func is_boxed_art_supported(p_text: String) -> bool:
	for c in p_text:
		if not boxed_map.has(c.to_lower()):
			return false
	return true
