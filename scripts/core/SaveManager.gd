extends Node
## JSON save/load for meta progression and run state.

const META_FILE := "user://meta_save.json"
const RUN_FILE := "user://run_save.json"
const SETTINGS_FILE := "user://settings.json"

func save_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s for write" % path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
