@tool
extends RefCounted
## Store object properties in an INI-style configuration file.


const CONFIG_PATH_PROPERTY := &"CONFIG_PATH"
const MAIN_SECTION_PROPERTY := &"MAIN_SECTION"
const MAIN_SECTION_DEFAULT := "main"

static var verbose: bool = false

static func _get_config_file(p_object: Object) -> String:
	var from_object_constant = p_object.get(CONFIG_PATH_PROPERTY)
	return from_object_constant if from_object_constant is String else ""


static func _get_main_section(p_object: Object) -> String:
	var from_object_constant = p_object.get(MAIN_SECTION_PROPERTY)
	return from_object_constant if from_object_constant != null else MAIN_SECTION_DEFAULT


static func _msg(p_text: String, p_arg1 = "") -> void:
	if verbose:
		print(p_text, p_arg1)


## Load object properties from config file and return status. [br]
## If p_config_path is empty, configuration path is taken from object's CONFIG_PATH property.
static func load_from_config(p_object: Object, p_config_path: String = "") -> int:
	var config_path: String = p_config_path
	if config_path.is_empty():
		config_path = _get_config_file(p_object)
	var section: String = _get_main_section(p_object)
	var config := ConfigFile.new()
	var err: int = config.load(config_path)
	if err != OK:
		_msg("ConfigMapper: Failed to load config: %s err_code: %d" % [config_path, err])
		return err
	_msg("ConfigMapper: Loading config: ", config_path)

	for prop_info in p_object.get_property_list():
		if prop_info.usage & PROPERTY_USAGE_CATEGORY and prop_info.hint_string.is_empty():
			_msg("ConfigMapper: Processing category: ", prop_info.name)
			section = prop_info.name
		elif prop_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop_info.usage & PROPERTY_USAGE_STORAGE:
			var value = null
			if config.has_section_key(section, prop_info.name):
				value = config.get_value(section, prop_info.name)
			if value != null and typeof(value) == prop_info.type:
				_msg("ConfigMapper: Loaded setting: %s section: %s value: %s" % [prop_info.name, section, value])
				p_object.set(prop_info.name, value)
	_msg("ConfigMapper: Finished with code: ", OK)
	return OK


## Save object properties to config file and return status. [br]
## If p_config_path is empty, configuration path is taken from object's CONFIG_PATH property. [br]
## WARNING: replaces file contents!
static func save_to_config(p_object: Object, p_config_path: String = "") -> int:
	var config_path: String = p_config_path
	if config_path.is_empty():
		config_path = _get_config_file(p_object)
	var section: String = _get_main_section(p_object)
	var config := ConfigFile.new()
	_msg("ConfigMapper: Saving config: ", config_path)

	for prop_info in p_object.get_property_list():
		if prop_info.usage & PROPERTY_USAGE_CATEGORY and prop_info.hint_string.is_empty():
			_msg("ConfigMapper: Processing category: ", prop_info.name)
			section = prop_info.name
		elif prop_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop_info.usage & PROPERTY_USAGE_STORAGE:
			_msg("ConfigMapper: Saving setting: %s section: %s value: %s" % [prop_info.name, section, p_object.get(prop_info.name)])
			config.set_value(section, prop_info.name, p_object.get(prop_info.name))

	var err: int = config.save(config_path)
	_msg("ConfigMapper: Finished with code: ", err)
	return err
