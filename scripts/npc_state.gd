class_name NPCState
extends RefCounted

## Authoritative runtime state for an individual NPC.
## Strictly engine-independent; spatial values use primitive dictionaries.

const MIN_STAT: float = 0.0
const MAX_STAT: float = 100.0

var npc_id: String = ""
var definition_id: String = ""

var position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var rotation: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var target_position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}

var health: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var stamina: float = 100.0
var alive: bool = true

var current_job: String = "IDLE"
var current_task: String = "IDLE"
var schedule_state: String = "REST"
var settlement_id: String = ""
var home_building_id: String = ""
var work_building_id: String = ""
var behavior_timer: float = 0.0
var home_position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}

func _init(p_npc_id: String = "", p_definition_id: String = "") -> void:
	npc_id = p_npc_id
	definition_id = p_definition_id

static func make_vector_dict(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Dictionary:
	return {"x": x, "y": y, "z": z}

func is_valid() -> bool:
	if npc_id.strip_edges().is_empty():
		return false
	if definition_id.strip_edges().is_empty():
		return false
	if health < MIN_STAT or health > MAX_STAT:
		return false
	if hunger < MIN_STAT or hunger > MAX_STAT:
		return false
	if thirst < MIN_STAT or thirst > MAX_STAT:
		return false
	if stamina < MIN_STAT or stamina > MAX_STAT:
		return false
	if not alive and health > 0.0:
		return false
	return true

func sanitize() -> void:
	health = clampf(health, MIN_STAT, MAX_STAT)
	hunger = clampf(hunger, MIN_STAT, MAX_STAT)
	thirst = clampf(thirst, MIN_STAT, MAX_STAT)
	stamina = clampf(stamina, MIN_STAT, MAX_STAT)
	if health <= MIN_STAT:
		alive = false

func update_needs(delta_seconds: float) -> void:
	if not alive:
		return
	hunger = clampf(hunger - (0.05 * delta_seconds), MIN_STAT, MAX_STAT)
	thirst = clampf(thirst - (0.10 * delta_seconds), MIN_STAT, MAX_STAT)
	stamina = clampf(stamina + (0.02 * delta_seconds), MIN_STAT, MAX_STAT)
	if hunger <= MIN_STAT or thirst <= MIN_STAT:
		health = clampf(health - (0.5 * delta_seconds), MIN_STAT, MAX_STAT)
		if health <= MIN_STAT:
			alive = false

func to_dict() -> Dictionary:
	return {
		"npc_id": npc_id,
		"definition_id": definition_id,
		"position": position.duplicate(),
		"rotation": rotation.duplicate(),
		"target_position": target_position.duplicate(),
		"health": health,
		"hunger": hunger,
		"thirst": thirst,
		"stamina": stamina,
		"alive": alive,
		"current_job": current_job,
		"current_task": current_task,
		"schedule_state": schedule_state,
		"settlement_id": settlement_id,
		"home_building_id": home_building_id,
		"work_building_id": work_building_id,
		"behavior_timer": behavior_timer,
		"home_position": home_position.duplicate()
	}

static func from_dict(data: Dictionary) -> NPCState:
	var state := NPCState.new()
	state.npc_id = data.get("npc_id", "")
	state.definition_id = data.get("definition_id", "")
	state.position = _extract_vector_dict(data.get("position", {}))
	state.rotation = _extract_vector_dict(data.get("rotation", {}))
	state.target_position = _extract_vector_dict(data.get("target_position", {}))
	state.health = float(data.get("health", 100.0))
	state.hunger = float(data.get("hunger", 100.0))
	state.thirst = float(data.get("thirst", 100.0))
	state.stamina = float(data.get("stamina", 100.0))
	state.alive = bool(data.get("alive", true))
	state.current_job = str(data.get("current_job", "IDLE"))
	state.current_task = str(data.get("current_task", "IDLE"))
	state.schedule_state = str(data.get("schedule_state", "REST"))
	state.settlement_id = str(data.get("settlement_id", ""))
	state.home_building_id = str(data.get("home_building_id", ""))
	state.work_building_id = str(data.get("work_building_id", ""))
	state.behavior_timer = float(data.get("behavior_timer", 0.0))
	state.home_position = _extract_vector_dict(data.get("home_position", {}))
	return state

static func _extract_vector_dict(data: Dictionary) -> Dictionary:
	return {
		"x": float(data.get("x", 0.0)),
		"y": float(data.get("y", 0.0)),
		"z": float(data.get("z", 0.0))
	}
