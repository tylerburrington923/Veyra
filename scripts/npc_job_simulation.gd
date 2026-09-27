class_name NPCJobSimulation
extends RefCounted

## Deterministic job execution layer.
## NPCState remains authoritative; this system only applies explicit job actions.

static func assign_job(state: NPCState, definition: JobDefinition, target_position: Dictionary) -> bool:
	if state == null or definition == null or not state.alive or not definition.is_valid():
		return false
	state.current_job = definition.id
	state.current_task = "MOVE_TO_WORK"
	state.schedule_state = "WORK"
	state.target_position = NPCState.make_vector_dict(
		float(target_position.get("x", 0.0)),
		float(target_position.get("y", 0.0)),
		float(target_position.get("z", 0.0))
	)
	return true

static func process_tick(state: NPCState, definition: JobDefinition, job: JobState, delta_seconds: float) -> bool:
	if state == null or definition == null or job == null or delta_seconds < 0.0:
		return false
	if not state.alive or job.completed or not job.active:
		return true

	if state.current_job != definition.id:
		state.current_job = definition.id
	if state.current_task == "IDLE":
		state.current_task = "MOVE_TO_WORK"
		state.schedule_state = "WORK"

	if state.current_task == "MOVE_TO_WORK":
		var distance := _distance_to_target(state)
		if distance <= 0.25:
			state.current_task = "WORK"
		else:
			var speed := maxf(0.0, definition.base_movement_speed)
			if speed > 0.0:
				var step := minf(distance, speed * delta_seconds)
				_move_toward_target(state, step)
		return true

	if state.current_task == "WORK":
		var work_rate := maxf(0.0, definition.base_work_speed)
		job.progress += work_rate * delta_seconds
		state.stamina = clampf(state.stamina - 0.04 * delta_seconds, NPCState.MIN_STAT, NPCState.MAX_STAT)
		if job.progress >= definition.work_duration:
			job.progress = definition.work_duration
			job.completed = true
			job.active = false
			state.current_task = "COMPLETE"
		return true

	return true

static func _distance_to_target(state: NPCState) -> float:
	var dx := float(state.target_position.get("x", 0.0)) - float(state.position.get("x", 0.0))
	var dy := float(state.target_position.get("y", 0.0)) - float(state.position.get("y", 0.0))
	var dz := float(state.target_position.get("z", 0.0)) - float(state.position.get("z", 0.0))
	return Vector3(dx, dy, dz).length()

static func _move_toward_target(state: NPCState, distance: float) -> void:
	var current := Vector3(
		float(state.position.get("x", 0.0)),
		float(state.position.get("y", 0.0)),
		float(state.position.get("z", 0.0))
	)
	var target := Vector3(
		float(state.target_position.get("x", 0.0)),
		float(state.target_position.get("y", 0.0)),
		float(state.target_position.get("z", 0.0))
	)
	var offset := target - current
	if offset.length_squared() <= 0.000001:
		return
	var next := current + offset.normalized() * minf(distance, offset.length())
	state.position = NPCState.make_vector_dict(next.x, next.y, next.z)
	if next.distance_squared_to(current) > 0.000001:
		var direction := (next - current).normalized()
		state.rotation = NPCState.make_vector_dict(0.0, atan2(-direction.x, -direction.z), 0.0)
