class_name EnemySimulation
extends RefCounted

static func process_tick(state: EnemyState, definition: EnemyDefinition, delta_seconds: float) -> bool:
	if state == null or definition == null or delta_seconds < 0.0:
		return false
	if delta_seconds == 0.0 or not state.alive:
		return true
	if state.health <= 0.0:
		state.alive = false
	return true
