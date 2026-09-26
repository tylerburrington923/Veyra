class_name NPCDefinition
extends RefCounted

## Static/configuration data for NPC archetypes.
## Strictly engine-independent: no Node, Vector3, Physics, or SceneTree dependencies.

var id: String = ""
var display_name: String = ""
var species: String = "human"
var base_movement_speed: float = 3.5
var base_work_speed: float = 1.0
var base_carry_capacity: int = 20
var preferred_jobs: Array[String] = []
var visual_archetype: String = "default"

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_species: String = "human",
	p_base_movement_speed: float = 3.5,
	p_base_work_speed: float = 1.0,
	p_base_carry_capacity: int = 20,
	p_preferred_jobs: Array[String] = [],
	p_visual_archetype: String = "default"
) -> void:
	id = p_id
	display_name = p_display_name
	species = p_species
	base_movement_speed = p_base_movement_speed
	base_work_speed = p_base_work_speed
	base_carry_capacity = p_base_carry_capacity
	preferred_jobs = p_preferred_jobs.duplicate()
	visual_archetype = p_visual_archetype

func is_valid() -> bool:
	if id.strip_edges().is_empty():
		return false
	if display_name.strip_edges().is_empty():
		return false
	if base_movement_speed < 0.0:
		return false
	if base_work_speed < 0.0:
		return false
	if base_carry_capacity < 0:
		return false
	return true

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"species": species,
		"base_movement_speed": base_movement_speed,
		"base_work_speed": base_work_speed,
		"base_carry_capacity": base_carry_capacity,
		"preferred_jobs": preferred_jobs.duplicate(),
		"visual_archetype": visual_archetype
	}

static func from_dict(data: Dictionary) -> NPCDefinition:
	var definition := NPCDefinition.new()
	definition.id = data.get("id", "")
	definition.display_name = data.get("display_name", "")
	definition.species = data.get("species", "human")
	definition.base_movement_speed = float(data.get("base_movement_speed", 3.5))
	definition.base_work_speed = float(data.get("base_work_speed", 1.0))
	definition.base_carry_capacity = int(data.get("base_carry_capacity", 20))
	var jobs_raw = data.get("preferred_jobs", [])
	var jobs_typed: Array[String] = []
	if jobs_raw is Array:
		for job in jobs_raw:
			jobs_typed.append(str(job))
	definition.preferred_jobs = jobs_typed
	definition.visual_archetype = data.get("visual_archetype", "default")
	return definition
