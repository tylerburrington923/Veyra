class_name AnimalSimulation
extends RefCounted

static func process_tick(state: AnimalState, definition: AnimalDefinition, delta_seconds: float) -> bool:
	if state == null or definition == null or delta_seconds < 0.0:
		return false
	if delta_seconds == 0.0 or not state.alive:
		return true
	state.hunger = clampf(state.hunger - definition.hunger_rate * delta_seconds, 0.0, 100.0)
	state.thirst = clampf(state.thirst - definition.thirst_rate * delta_seconds, 0.0, 100.0)
	if state.hunger <= 0.0 or state.thirst <= 0.0:
		state.health = clampf(state.health - 0.5 * delta_seconds, 0.0, definition.max_health)
		if state.health <= 0.0:
			state.alive = false
	return true
