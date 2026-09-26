class_name NPCSimulation
extends RefCounted

## Deterministic processing engine for NPC runtime state.
## Engine-independent data processor; consumes explicit time and mutates NPCState.

## Process one deterministic simulation tick for an individual NPC.
## Returns false for invalid inputs; returns true when the tick is accepted.
static func process_tick(state: NPCState, definition: NPCDefinition, delta_seconds: float) -> bool:
	if state == null or definition == null:
		return false
	if delta_seconds < 0.0:
		return false
	if delta_seconds == 0.0 or not state.alive:
		return true

	state.update_needs(delta_seconds)
	return true

## Process a batch using definition IDs stored in each NPCState.
## Returns the number of accepted ticks.
static func process_batch(states: Array[NPCState], definitions: Dictionary, delta_seconds: float) -> int:
	if delta_seconds < 0.0:
		return 0

	var processed_count: int = 0
	for state in states:
		if state == null:
			continue
		var def_id: String = state.definition_id
		if not definitions.has(def_id):
			continue
		var definition: NPCDefinition = definitions[def_id]
		if process_tick(state, definition, delta_seconds):
			processed_count += 1

	return processed_count
