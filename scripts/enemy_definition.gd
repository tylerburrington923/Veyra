class_name EnemyDefinition
extends RefCounted

var id: String = ""
var display_name: String = ""
var archetype: String = "MELEE"
var max_health: float = 100.0
var movement_speed: float = 4.0
var attack_damage: float = 10.0
var attack_range: float = 1.5
var detection_range: float = 12.0
var behavior_archetype: String = "AGGRESSIVE"

func _init(p_id: String = "", p_display_name: String = "", p_archetype: String = "MELEE", p_max_health: float = 100.0, p_movement_speed: float = 4.0, p_attack_damage: float = 10.0, p_attack_range: float = 1.5, p_detection_range: float = 12.0, p_behavior_archetype: String = "AGGRESSIVE") -> void:
	id = p_id
	display_name = p_display_name
	archetype = p_archetype
	max_health = p_max_health
	movement_speed = p_movement_speed
	attack_damage = p_attack_damage
	attack_range = p_attack_range
	detection_range = p_detection_range
	behavior_archetype = p_behavior_archetype

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and not display_name.strip_edges().is_empty() and max_health > 0.0 and movement_speed >= 0.0 and attack_damage >= 0.0 and attack_range >= 0.0 and detection_range >= 0.0

func to_dict() -> Dictionary:
	return {"id": id, "display_name": display_name, "archetype": archetype, "max_health": max_health, "movement_speed": movement_speed, "attack_damage": attack_damage, "attack_range": attack_range, "detection_range": detection_range, "behavior_archetype": behavior_archetype}

static func from_dict(data: Dictionary) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.display_name = str(data.get("display_name", ""))
	definition.archetype = str(data.get("archetype", "MELEE"))
	definition.max_health = float(data.get("max_health", 100.0))
	definition.movement_speed = float(data.get("movement_speed", 4.0))
	definition.attack_damage = float(data.get("attack_damage", 10.0))
	definition.attack_range = float(data.get("attack_range", 1.5))
	definition.detection_range = float(data.get("detection_range", 12.0))
	definition.behavior_archetype = str(data.get("behavior_archetype", "AGGRESSIVE"))
	return definition
