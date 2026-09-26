class_name ProductionManager
extends RefCounted

var _definitions: Dictionary = {}
var _active_productions: Dictionary = {}

func register_definition(definition: ProductionDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	_definitions[definition.id] = definition
	return true

func get_definition(definition_id: String) -> ProductionDefinition:
	return _definitions.get(definition_id, null)

func create_production(production_id: String, definition_id: String, source_building_id: String = "") -> ProductionState:
	if production_id.is_empty() or _active_productions.has(production_id) or not _definitions.has(definition_id):
		return null
	var state := ProductionState.new(production_id, definition_id)
	state.source_building_id = source_building_id
	_active_productions[production_id] = state
	return state

func advance_progress(production_id: String, delta_seconds: float) -> bool:
	if delta_seconds < 0.0:
		return false
	var state: ProductionState = _active_productions.get(production_id, null)
	if state == null or not state.active:
		return false
	var definition: ProductionDefinition = _definitions[state.definition_id]
	state.progress += delta_seconds
	if state.progress >= definition.duration:
		state.progress = definition.duration
		state.active = false
		return true
	return false
