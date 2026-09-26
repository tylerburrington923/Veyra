class_name JobDefinition
extends RefCounted

var id: String = ""
var display_name: String = ""
var category: String = "GENERAL"
var priority: int = 1
var allowed_worker_types: Array[String] = []
var required_building_types: Array[String] = []
var required_tools: Array[String] = []
var work_duration: float = 5.0
var production_id: String = ""

func _init(p_id: String = "", p_display_name: String = "", p_category: String = "GENERAL", p_priority: int = 1, p_allowed_worker_types: Array[String] = [], p_required_building_types: Array[String] = [], p_required_tools: Array[String] = [], p_work_duration: float = 5.0, p_production_id: String = "") -> void:
	id = p_id
	display_name = p_display_name
	category = p_category
	priority = p_priority
	allowed_worker_types = p_allowed_worker_types.duplicate()
	required_building_types = p_required_building_types.duplicate()
	required_tools = p_required_tools.duplicate()
	work_duration = p_work_duration
	production_id = p_production_id

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and not display_name.strip_edges().is_empty() and priority >= 0 and work_duration >= 0.0

func to_dict() -> Dictionary:
	return {"id": id, "display_name": display_name, "category": category, "priority": priority, "allowed_worker_types": allowed_worker_types.duplicate(), "required_building_types": required_building_types.duplicate(), "required_tools": required_tools.duplicate(), "work_duration": work_duration, "production_id": production_id}

static func from_dict(data: Dictionary) -> JobDefinition:
	var definition := JobDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.display_name = str(data.get("display_name", ""))
	definition.category = str(data.get("category", "GENERAL"))
	definition.priority = int(data.get("priority", 1))
	definition.work_duration = float(data.get("work_duration", 5.0))
	definition.production_id = str(data.get("production_id", ""))
	for value in data.get("allowed_worker_types", []):
		definition.allowed_worker_types.append(str(value))
	for value in data.get("required_building_types", []):
		definition.required_building_types.append(str(value))
	for value in data.get("required_tools", []):
		definition.required_tools.append(str(value))
	return definition
