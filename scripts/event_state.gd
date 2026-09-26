class_name EventState
extends RefCounted

var event_id: String = ""
var definition_id: String = ""
var time_remaining: float = 0.0
var active: bool = false

func _init(p_event_id: String = "", p_definition_id: String = "") -> void:
	event_id = p_event_id
	definition_id = p_definition_id

func is_valid() -> bool:
	return not event_id.strip_edges().is_empty() and not definition_id.strip_edges().is_empty() and time_remaining >= 0.0

func to_dict() -> Dictionary:
	return {"event_id": event_id, "definition_id": definition_id, "time_remaining": time_remaining, "active": active}

static func from_dict(data: Dictionary) -> EventState:
	var state := EventState.new()
	state.event_id = str(data.get("event_id", ""))
	state.definition_id = str(data.get("definition_id", ""))
	state.time_remaining = float(data.get("time_remaining", 0.0))
	state.active = bool(data.get("active", false))
	return state
