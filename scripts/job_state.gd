class_name JobState
extends RefCounted

var job_id: String = ""
var definition_id: String = ""
var assigned_worker_id: String = ""
var target_building_id: String = ""
var progress: float = 0.0
var active: bool = false
var completed: bool = false

func _init(p_job_id: String = "", p_definition_id: String = "") -> void:
	job_id = p_job_id
	definition_id = p_definition_id

func is_valid() -> bool:
	return not job_id.strip_edges().is_empty() and not definition_id.strip_edges().is_empty() and progress >= 0.0

func sanitize() -> void:
	progress = maxf(progress, 0.0)

func to_dict() -> Dictionary:
	return {"job_id": job_id, "definition_id": definition_id, "assigned_worker_id": assigned_worker_id, "target_building_id": target_building_id, "progress": progress, "active": active, "completed": completed}

static func from_dict(data: Dictionary) -> JobState:
	var state := JobState.new()
	state.job_id = str(data.get("job_id", ""))
	state.definition_id = str(data.get("definition_id", ""))
	state.assigned_worker_id = str(data.get("assigned_worker_id", ""))
	state.target_building_id = str(data.get("target_building_id", ""))
	state.progress = float(data.get("progress", 0.0))
	state.active = bool(data.get("active", false))
	state.completed = bool(data.get("completed", false))
	return state
