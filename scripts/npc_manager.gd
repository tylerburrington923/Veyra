class_name NPCManager
extends Node3D

## Runtime bridge between authoritative NPCState data and NPCController presentation.
## The manager owns runtime NPC states; controllers are disposable presentation nodes.
## SettlementManager remains the owner of settlement membership data.

@export var spawn_radius: float = 3.0

var definitions: Dictionary = {}
var states: Dictionary = {}
var controllers: Dictionary = {}

func _ready() -> void:
	add_to_group("npc_manager")
	_register_default_definitions()
	if SettlementManager and SettlementManager.has_signal("settlement_changed"):
		SettlementManager.settlement_changed.connect(_on_settlement_changed)
	call_deferred("_ensure_beta_villager")
	call_deferred("sync_settlement_villagers")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var typed_states: Array[NPCState] = []
	for state in states.values():
		if state is NPCState:
			typed_states.append(state)
	if not typed_states.is_empty():
		NPCSimulation.process_batch(typed_states, definitions, delta)
		for state in typed_states:
			_update_villager_behavior(state, delta)
	for npc_id in controllers:
		var controller: NPCController = controllers[npc_id]
		var state: NPCState = states.get(npc_id)
		if controller and state:
			controller.apply_authoritative_state(state)

func _register_default_definitions() -> void:
	definitions["human_worker"] = NPCDefinition.new("human_worker", "Worker", "human", 3.5, 1.0, 20, ["BUILD", "GATHER"], "worker_01")
	definitions["human_villager"] = NPCDefinition.new("human_villager", "Villager", "human", 3.0, 1.0, 20, ["GATHER", "BUILD"], "villager_01")

func _ensure_beta_villager() -> void:
	if not SettlementManager or not SettlementManager.villagers.is_empty():
		return
	SettlementManager.add_villager("villager_beta_01", "Aren")

func spawn_npc(npc_id: String, definition_id: String, position: Vector3) -> NPCController:
	if npc_id.is_empty() or states.has(npc_id) or not definitions.has(definition_id):
		return null
	var definition: NPCDefinition = definitions[definition_id]
	var state := NPCState.new(npc_id, definition_id)
	state.position = NPCState.make_vector_dict(position.x, position.y, position.z)
	states[npc_id] = state

	var controller := NPCController.new()
	controller.name = "NPC_" + npc_id
	add_child(controller)
	controller.configure(definition, state)
	controllers[npc_id] = controller
	return controller

func despawn_npc(npc_id: String) -> void:
	states.erase(npc_id)
	var controller: NPCController = controllers.get(npc_id)
	if controller:
		controller.queue_free()
	controllers.erase(npc_id)

func get_npc_state(npc_id: String) -> NPCState:
	return states.get(npc_id) as NPCState

func sync_settlement_villagers() -> void:
	if not SettlementManager:
		return
	var villagers: Dictionary = SettlementManager.villagers
	var live_ids: Dictionary = {}
	var index: int = 0

	for villager_id in villagers:
		var id := str(villager_id)
		var record = villagers[villager_id]
		if not record is Dictionary:
			continue
		live_ids[id] = true
		var definition_id := "human_villager"
		var job := str(record.get("job", ""))
		if job == "Builder" or job == "BUILD":
			definition_id = "human_worker"

		var state: NPCState = states.get(id)
		if not state:
			spawn_npc(id, definition_id, _get_villager_spawn_position(record, index))
			state = states.get(id)
			index += 1
		if state:
			state.current_job = job if not job.is_empty() else "IDLE"

	for existing_id in states.keys():
		if not live_ids.has(existing_id):
			despawn_npc(str(existing_id))

func _get_villager_spawn_position(record: Dictionary, index: int) -> Vector3:
	var position_data = record.get("position", {})
	if position_data is Dictionary:
		return Vector3(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)), float(position_data.get("z", 0.0)))
	var angle := float(index) * 2.39996323
	return _get_settlement_center() + Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius

func _get_settlement_center() -> Vector3:
	if not SettlementManager:
		return Vector3.ZERO
	for building in SettlementManager.buildings.values():
		if building is Dictionary:
			var raw_position = building.get("position", [])
			if raw_position is Array and raw_position.size() >= 3:
				return Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	return Vector3.ZERO

func _on_settlement_changed() -> void:
	call_deferred("sync_settlement_villagers")

func _ground_position(position: Vector3) -> Vector3:
	var generator := get_tree().get_first_node_in_group("world_generator")
	if generator and generator.has_method("get_height_at_world"):
		position.y = float(generator.get_height_at_world(position.x, position.z)) + 0.05
	return position

func _update_villager_behavior(state: NPCState, delta: float) -> void:
	if state.current_job != "IDLE" and state.current_job != "Unassigned":
		return
	state.behavior_timer += delta
	if state.current_task == "IDLE" and state.behavior_timer >= 5.0 + float(abs(state.npc_id.hash()) % 5):
		state.behavior_timer = 0.0
		var current := _state_position(state.position)
		var phase := float(abs(state.npc_id.hash()) % 360) * 0.0174533
		var target := _ground_position(current + Vector3(cos(phase), 0.0, sin(phase)) * 3.5)
		state.target_position = NPCState.make_vector_dict(target.x, target.y, target.z)
		state.current_task = "WANDER"
		return
	if state.current_task == "WANDER":
		var current := _state_position(state.position)
		var target := _state_position(state.target_position)
		var offset := target - current
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.25 or state.behavior_timer >= 9.0:
			state.position = _vector_dict(_ground_position(current))
			state.current_task = "IDLE"
			state.behavior_timer = 0.0
			return
		var step := minf(3.0 * delta, distance)
		var next := _ground_position(current + offset.normalized() * step)
		state.position = _vector_dict(next)

func _state_position(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))

func _vector_dict(position: Vector3) -> Dictionary:
	return {"x": position.x, "y": position.y, "z": position.z}
