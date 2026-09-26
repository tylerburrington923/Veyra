class_name ProductionState
extends RefCounted

var production_id: String = ""
var definition_id: String = ""
var active: bool = false
var progress: float = 0.0
var assigned_worker_id: String = ""
var source_building_id: String = ""

func _init(p_production_id: String = "", p_definition_id: String = "") -> void:
	production_id = p_production_id
	definition_id = p_definition_id

func is_valid() -> bool:
	return not production_id.strip_edges().is_empty() and not definition_id.strip_edges().is_empty() and progress >= 0.0

func sanitize() -> void:
	progress = maxf(progress, 0.0)

func to_dict() -> Dictionary:
	return {"production_id": production_id, "definition_id": definition_id, "active": active, "progress": progress, "assigned_worker_id": assigned_worker_id, "source_building_id": source_building_id}

static func from_dict(data: Dictionary) -> ProductionState:
	var state := ProductionState.new()
	state.production_id = str(data.get("production_id", ""))
	state.definition_id = str(data.get("definition_id", ""))
	state.active = bool(data.get("active", false))
	state.progress = float(data.get("progress", 0.0))
	state.assigned_worker_id = str(data.get("assigned_worker_id", ""))
	state.source_building_id = str(data.get("source_building_id", ""))
	return state
