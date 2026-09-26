class_name EventDefinition
extends RefCounted

var id: String = ""
var display_name: String = ""
var duration: float = 60.0

func _init(p_id: String = "", p_display_name: String = "", p_duration: float = 60.0) -> void:
	id = p_id
	display_name = p_display_name
	duration = p_duration

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and not display_name.strip_edges().is_empty() and duration >= 0.0

func to_dict() -> Dictionary:
	return {"id": id, "display_name": display_name, "duration": duration}

static func from_dict(data: Dictionary) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.display_name = str(data.get("display_name", ""))
	definition.duration = float(data.get("duration", 60.0))
	return definition
