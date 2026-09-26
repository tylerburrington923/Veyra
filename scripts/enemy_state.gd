class_name EnemyState
extends RefCounted

var enemy_id: String = ""
var definition_id: String = ""
var position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var rotation: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var target_position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var health: float = 100.0
var alive: bool = true
var current_target_id: String = ""
var behavior_state: String = "IDLE"

func _init(p_enemy_id: String = "", p_definition_id: String = "") -> void:
	enemy_id = p_enemy_id
	definition_id = p_definition_id

func is_valid() -> bool:
	if enemy_id.strip_edges().is_empty() or definition_id.strip_edges().is_empty():
		return false
	if health < 0.0 or health > 1000.0:
		return false
	return alive or health <= 0.0

func sanitize() -> void:
	health = clampf(health, 0.0, 1000.0)
	if health <= 0.0:
		alive = false

func to_dict() -> Dictionary:
	return {"enemy_id": enemy_id, "definition_id": definition_id, "position": position.duplicate(), "rotation": rotation.duplicate(), "target_position": target_position.duplicate(), "health": health, "alive": alive, "current_target_id": current_target_id, "behavior_state": behavior_state}

static func from_dict(data: Dictionary) -> EnemyState:
	var state := EnemyState.new()
	state.enemy_id = str(data.get("enemy_id", ""))
	state.definition_id = str(data.get("definition_id", ""))
	state.position = _vector_dict(data.get("position", {}))
	state.rotation = _vector_dict(data.get("rotation", {}))
	state.target_position = _vector_dict(data.get("target_position", {}))
	state.health = float(data.get("health", 100.0))
	state.alive = bool(data.get("alive", true))
	state.current_target_id = str(data.get("current_target_id", ""))
	state.behavior_state = str(data.get("behavior_state", "IDLE"))
	return state

static func _vector_dict(value: Variant) -> Dictionary:
	var data: Dictionary = value if value is Dictionary else {}
	return {"x": float(data.get("x", 0.0)), "y": float(data.get("y", 0.0)), "z": float(data.get("z", 0.0))}
