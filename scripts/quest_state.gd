class_name QuestState
extends RefCounted

var quest_id: String = ""
var definition_id: String = ""
var completed_objectives: Array[String] = []
var is_completed: bool = false

func _init(p_quest_id: String = "", p_definition_id: String = "") -> void:
	quest_id = p_quest_id
	definition_id = p_definition_id

func is_valid() -> bool:
	return not quest_id.strip_edges().is_empty() and not definition_id.strip_edges().is_empty()

func to_dict() -> Dictionary:
	return {"quest_id": quest_id, "definition_id": definition_id, "completed_objectives": completed_objectives.duplicate(), "is_completed": is_completed}

static func from_dict(data: Dictionary) -> QuestState:
	var state := QuestState.new()
	state.quest_id = str(data.get("quest_id", ""))
	state.definition_id = str(data.get("definition_id", ""))
	state.is_completed = bool(data.get("is_completed", false))
	for objective in data.get("completed_objectives", []):
		state.completed_objectives.append(str(objective))
	return state
