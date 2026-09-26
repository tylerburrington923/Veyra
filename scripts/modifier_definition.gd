class_name ModifierDefinition
extends RefCounted

enum ModifierType { ADDITIVE, MULTIPLICATIVE, OVERRIDE }

var id: String = ""
var target_stat: String = ""
var type: ModifierType = ModifierType.ADDITIVE
var value: float = 0.0

func _init(p_id: String = "", p_target_stat: String = "", p_type: ModifierType = ModifierType.ADDITIVE, p_value: float = 0.0) -> void:
	id = p_id
	target_stat = p_target_stat
	type = p_type
	value = p_value

func is_valid() -> bool:
	return not id.strip_edges().is_empty() and not target_stat.strip_edges().is_empty()

func to_dict() -> Dictionary:
	return {"id": id, "target_stat": target_stat, "type": int(type), "value": value}

static func from_dict(data: Dictionary) -> ModifierDefinition:
	var definition := ModifierDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.target_stat = str(data.get("target_stat", ""))
	definition.type = int(data.get("type", ModifierType.ADDITIVE)) as ModifierType
	definition.value = float(data.get("value", 0.0))
	return definition
