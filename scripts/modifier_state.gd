class_name ModifierState
extends RefCounted

var instance_id: String = ""
var modifier_id: String = ""
var duration_remaining: float = -1.0
var is_active: bool = true

func _init(p_instance_id: String = "", p_modifier_id: String = "") -> void:
	instance_id = p_instance_id
	modifier_id = p_modifier_id

func is_valid() -> bool:
	return not instance_id.strip_edges().is_empty() and not modifier_id.strip_edges().is_empty() and (duration_remaining >= 0.0 or is_equal_approx(duration_remaining, -1.0))

func to_dict() -> Dictionary:
	return {"instance_id": instance_id, "modifier_id": modifier_id, "duration_remaining": duration_remaining, "is_active": is_active}

static func from_dict(data: Dictionary) -> ModifierState:
	var state := ModifierState.new()
	state.instance_id = str(data.get("instance_id", ""))
	state.modifier_id = str(data.get("modifier_id", ""))
	state.duration_remaining = float(data.get("duration_remaining", -1.0))
	state.is_active = bool(data.get("is_active", true))
	return state
