class_name ProductionDefinition
extends RefCounted

var id: String = ""
var inputs: Dictionary = {}
var outputs: Dictionary = {}
var duration: float = 10.0
var required_building: String = ""
var required_job: String = ""
var enabled: bool = true

func _init(p_id: String = "", p_inputs: Dictionary = {}, p_outputs: Dictionary = {}, p_duration: float = 10.0, p_required_building: String = "", p_required_job: String = "", p_enabled: bool = true) -> void:
	id = p_id
	inputs = p_inputs.duplicate()
	outputs = p_outputs.duplicate()
	duration = p_duration
	required_building = p_required_building
	required_job = p_required_job
	enabled = p_enabled

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and duration >= 0.0

func to_dict() -> Dictionary:
	return {"id": id, "inputs": inputs.duplicate(), "outputs": outputs.duplicate(), "duration": duration, "required_building": required_building, "required_job": required_job, "enabled": enabled}

static func from_dict(data: Dictionary) -> ProductionDefinition:
	var definition := ProductionDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.inputs = data.get("inputs", {}).duplicate()
	definition.outputs = data.get("outputs", {}).duplicate()
	definition.duration = float(data.get("duration", 10.0))
	definition.required_building = str(data.get("required_building", ""))
	definition.required_job = str(data.get("required_job", ""))
	definition.enabled = bool(data.get("enabled", true))
	return definition
