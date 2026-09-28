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

func can_start(definition_id: String, stock: Dictionary) -> bool:
	var definition: ProductionDefinition = _definitions.get(definition_id, null)
	if definition == null or not definition.enabled:
		return false
	for resource_type in definition.inputs.keys():
		if int(stock.get(str(resource_type), 0)) < int(definition.inputs[resource_type]):
			return false
	return true

func start_production(production_id: String, definition_id: String, stock: Dictionary, source_building_id: String, worker_id: String) -> ProductionState:
	if production_id.is_empty() or _active_productions.has(production_id):
		return null
	if not can_start(definition_id, stock):
		return null
	var definition: ProductionDefinition = _definitions.get(definition_id, null)
	if definition == null:
		return null
	for resource_type in definition.inputs.keys():
		var key := str(resource_type)
		stock[key] = int(stock.get(key, 0)) - int(definition.inputs[resource_type])
	var state := ProductionState.new(production_id, definition_id)
	state.source_building_id = source_building_id
	state.assigned_worker_id = worker_id
	state.active = true
	state.progress = 0.0
	_active_productions[production_id] = state
	return state

func complete_production(production_id: String, stock: Dictionary) -> bool:
	var state: ProductionState = _active_productions.get(production_id, null)
	if state == null or state.active:
		return false
	var definition: ProductionDefinition = _definitions.get(state.definition_id, null)
	if definition == null:
		_active_productions.erase(production_id)
		return false
	for resource_type in definition.outputs.keys():
		var key := str(resource_type)
		stock[key] = int(stock.get(key, 0)) + int(definition.outputs[resource_type])
	_active_productions.erase(production_id)
	return true

func cancel_production(production_id: String, stock: Dictionary, refund_inputs: bool = true) -> bool:
	var state: ProductionState = _active_productions.get(production_id, null)
	if state == null:
		return false
	var definition: ProductionDefinition = _definitions.get(state.definition_id, null)
	if definition != null and refund_inputs:
		for resource_type in definition.inputs.keys():
			var key := str(resource_type)
			stock[key] = int(stock.get(key, 0)) + int(definition.inputs[resource_type])
	_active_productions.erase(production_id)
	return true

func set_progress(production_id: String, progress: float) -> bool:
	var state: ProductionState = _active_productions.get(production_id, null)
	if state == null or not state.active:
		return false
	var definition: ProductionDefinition = _definitions.get(state.definition_id, null)
	if definition == null:
		return false
	state.progress = clampf(progress, 0.0, definition.duration)
	if state.progress >= definition.duration:
		state.active = false
	return true

func get_active_productions() -> Dictionary:
	return _active_productions.duplicate(true)

func load_states(records: Dictionary) -> void:
	_active_productions.clear()
	for key in records.keys():
		var data = records[key]
		if not data is Dictionary:
			continue
		var state := ProductionState.from_dict(data)
		var definition: ProductionDefinition = _definitions.get(state.definition_id, null)
		if definition != null and state.is_valid() and state.active:
			state.progress = clampf(state.progress, 0.0, definition.duration)
			_active_productions[str(key)] = state

func serialize_states() -> Dictionary:
	var result := {}
	for key in _active_productions.keys():
		var state: ProductionState = _active_productions[key]
		if state != null and state.is_valid():
			result[str(key)] = state.to_dict()
	return result

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
