class_name QuestDefinition
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
var required_objectives: Array[String] = []

func _init(p_id: String = "", p_title: String = "", p_description: String = "") -> void:
	id = p_id
	title = p_title
	description = p_description

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and not title.strip_edges().is_empty()

func to_dict() -> Dictionary:
	return {"id": id, "title": title, "description": description, "required_objectives": required_objectives.duplicate()}

static func from_dict(data: Dictionary) -> QuestDefinition:
	var definition := QuestDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.title = str(data.get("title", ""))
	definition.description = str(data.get("description", ""))
	for objective in data.get("required_objectives", []):
		definition.required_objectives.append(str(objective))
	return definition
