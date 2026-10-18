extends RefCounted
const BASE := "res://art/painted/"
var data: Dictionary
var textures := {}

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(BASE + "environments.json"))

func has_region(id: String) -> bool:
	return data.has(id)

func texture(id: String, role: String) -> Texture2D:
	var path: String = data[id][role]
	if not textures.has(path):
		textures[path] = load(BASE + path)
	return textures[path]
