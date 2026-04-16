class_name LPCPresetLoader
extends Object
## Reads character preset JSON from res://assets/characters/<id>.json.
## Parallel agent will mirror tools/characters/*.json here; if nothing is
## present yet we ship a minimal barbarian_human.json.

const DIR := "res://assets/characters/"

static func load_preset(id: String) -> Dictionary:
	var path := DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("LPCPresetLoader: preset not found %s" % path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		push_warning("LPCPresetLoader: empty preset %s" % path)
		return {}
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("LPCPresetLoader: malformed preset %s" % path)
		return {}
	return data

static func load_with_fallback(id: String, fallback_id: String = "barbarian_human") -> Dictionary:
	var d := load_preset(id)
	if d.is_empty() and id != fallback_id:
		push_warning("LPCPresetLoader: falling back to %s for missing %s" % [fallback_id, id])
		d = load_preset(fallback_id)
	return d
