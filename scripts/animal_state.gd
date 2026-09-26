class_name AnimalState
extends RefCounted

const MIN_STAT: float = 0.0
const MAX_STAT: float = 100.0

var animal_id: String = ""
var definition_id: String = ""
var position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var rotation: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var target_position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var health: float = 50.0
var hunger: float = 100.0
var thirst: float = 100.0
var stamina: float = 100.0
var alive: bool = true
var behavior_state: String = "IDLE"

func _init(p_animal_id: String = "", p_definition_id: String = "") -> void:
	animal_id = p_animal_id
	definition_id = p_definition_id

func is_valid() -> bool:
	if animal_id.strip_edges().is_empty() or definition_id.strip_edges().is_empty():
		return false
	if health < MIN_STAT or health > 200.0 or hunger < MIN_STAT or hunger > MAX_STAT or thirst < MIN_STAT or thirst > MAX_STAT or stamina < MIN_STAT or stamina > MAX_STAT:
		return false
	if not alive and health > MIN_STAT:
		return false
	return true

func sanitize() -> void:
	health = clampf(health, MIN_STAT, 200.0)
	hunger = clampf(hunger, MIN_STAT, MAX_STAT)
	thirst = clampf(thirst, MIN_STAT, MAX_STAT)
	stamina = clampf(stamina, MIN_STAT, MAX_STAT)
	if health <= MIN_STAT:
		alive = false

func to_dict() -> Dictionary:
	return {"animal_id": animal_id, "definition_id": definition_id, "position": position.duplicate(), "rotation": rotation.duplicate(), "target_position": target_position.duplicate(), "health": health, "hunger": hunger, "thirst": thirst, "stamina": stamina, "alive": alive, "behavior_state": behavior_state}

static func from_dict(data: Dictionary) -> AnimalState:
	var state := AnimalState.new()
	state.animal_id = str(data.get("animal_id", ""))
	state.definition_id = str(data.get("definition_id", ""))
	state.position = _vector_dict(data.get("position", {}))
	state.rotation = _vector_dict(data.get("rotation", {}))
	state.target_position = _vector_dict(data.get("target_position", {}))
	state.health = float(data.get("health", 50.0))
	state.hunger = float(data.get("hunger", 100.0))
	state.thirst = float(data.get("thirst", 100.0))
	state.stamina = float(data.get("stamina", 100.0))
	state.alive = bool(data.get("alive", true))
	state.behavior_state = str(data.get("behavior_state", "IDLE"))
	return state

static func _vector_dict(value: Variant) -> Dictionary:
	var data: Dictionary = value if value is Dictionary else {}
	return {"x": float(data.get("x", 0.0)), "y": float(data.get("y", 0.0)), "z": float(data.get("z", 0.0))}
