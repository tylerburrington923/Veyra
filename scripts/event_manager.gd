class_name EventManager
extends RefCounted

var _definitions: Dictionary = {}
var _active_events: Dictionary = {}

func register_definition(definition: EventDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	_definitions[definition.id] = definition
	return true

func get_definition(definition_id: String) -> EventDefinition:
	return _definitions.get(definition_id, null)

func trigger_event(event_id: String, definition_id: String) -> EventState:
	if event_id.is_empty() or _active_events.has(event_id) or not _definitions.has(definition_id):
		return null
	var definition: EventDefinition = _definitions[definition_id]
	var state := EventState.new(event_id, definition_id)
	state.time_remaining = definition.duration
	state.active = true
	_active_events[event_id] = state
	return state
