class_name NPCManager
extends Node3D

func _settlement_manager() -> VeyraSettlementManager:
	return get_node_or_null("/root/SettlementManager") as VeyraSettlementManager

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
	var settlement := _settlement_manager()
	if settlement and settlement.has_signal("settlement_changed"):
		settlement.settlement_changed.connect(_on_settlement_changed)
	call_deferred("_ensure_beta_villager")
	call_deferred("sync_settlement_villagers")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var network_manager = get_node_or_null("/root/NetworkManager")
	var network_client := network_manager != null and bool(network_manager.get("session_active")) and not bool(network_manager.get("is_host"))
	var typed_states: Array[NPCState] = []
	for state in states.values():
		if state is NPCState:
			typed_states.append(state)
	if not typed_states.is_empty() and not network_client:
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
	var settlement := _settlement_manager()
	if not settlement or not settlement.villagers.is_empty():
		return
	settlement.add_villager("villager_beta_01", "Aren")

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
	var settlement := _settlement_manager()
	if not settlement:
		return
	var villagers: Dictionary = settlement.villagers
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
			state.current_job = job if not job.is_empty() else _default_role_for_npc(id)

	for existing_id in states.keys():
		if not live_ids.has(existing_id):
			despawn_npc(str(existing_id))

func _default_role_for_npc(npc_id: String) -> String:
	return "TRADER" if abs(npc_id.hash()) % 3 == 0 else "BUILDER"

func interact_with_npc(npc_id: String, player: Node) -> String:
	var state := states.get(npc_id) as NPCState
	if not state or not state.alive or not player:
		return "No response."
	var inventory: VeyraInventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return "No inventory available."
	match state.current_job:
		"TRADER":
			if inventory.has_resource("Stone", 5):
				var paid := inventory.remove_resource("Stone", 5)
				if paid == 5 and inventory.add_resource("Metal", 1) == 1:
					return "%s traded 5 Stone for 1 Metal." % _npc_name(npc_id)
				if paid > 0:
					inventory.add_resource("Stone", paid)
			return "%s: bring 5 Stone for 1 Metal." % _npc_name(npc_id)
		"BUILDER":
			if inventory.has_item("I01_STONE_AXE"):
				return "%s: I can service your tools, but your Stone Axe is already made." % _npc_name(npc_id)
			if inventory.has_resource("Wood", 2) and inventory.has_resource("Stone", 2):
				if inventory.remove_resource("Wood", 2) == 2 and inventory.remove_resource("Stone", 2) == 2 and inventory.add_item("I01_STONE_AXE", 1) == 1:
					return "%s crafted a Stone Axe for you." % _npc_name(npc_id)
				inventory.add_resource("Wood", 2)
				inventory.add_resource("Stone", 2)
			return "%s service: 2 Wood + 2 Stone for a Stone Axe." % _npc_name(npc_id)
	return "%s has nothing to offer right now." % _npc_name(npc_id)

func _npc_name(npc_id: String) -> String:
	var settlement := _settlement_manager()
	if settlement and settlement.villagers.has(npc_id):
		return str(settlement.villagers[npc_id].get("name", "Villager"))
	return "Villager"

func _get_villager_spawn_position(record: Dictionary, index: int) -> Vector3:
	var position_data = record.get("position", {})
	if position_data is Dictionary:
		return Vector3(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)), float(position_data.get("z", 0.0)))
	var angle := float(index) * 2.39996323
	return _get_settlement_center() + Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius

func _get_settlement_center() -> Vector3:
	var settlement := _settlement_manager()
	if not settlement:
		return Vector3.ZERO
	for building in settlement.buildings.values():
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
	if not state.alive:
		return
	state.behavior_timer += delta
	var current := _state_position(state.position)
	var work_target := _get_npc_work_target(state)

	if state.current_task == "IDLE":
		var delay := 4.0 + float(abs(state.npc_id.hash()) % 4)
		if state.behavior_timer < delay:
			return
		state.behavior_timer = 0.0
		if state.current_job == "BUILDER" or state.current_job == "Builder":
			state.current_task = "WORK"
			state.target_position = _vector_dict(work_target)
		elif state.current_job == "TRADER" or state.current_job == "Trader":
			state.current_task = "PATROL"
			var phase := float((abs(state.npc_id.hash()) + int(state.behavior_timer)) % 360) * 0.0174533
			var patrol_target := _ground_position(_get_settlement_center() + Vector3(cos(phase), 0.0, sin(phase)) * 4.0)
			state.target_position = _vector_dict(patrol_target)
		else:
			var phase := float(abs(state.npc_id.hash()) % 360) * 0.0174533
			state.current_task = "WANDER"
			state.target_position = _vector_dict(_ground_position(current + Vector3(cos(phase), 0.0, sin(phase)) * 3.5))
		return

	if state.current_task == "WORK":
		if current.distance_to(work_target) > 0.65:
			_move_state_toward(state, work_target, delta)
			return
		if state.behavior_timer >= 3.0:
			state.behavior_timer = 0.0
			var settlement := _settlement_manager()
			if settlement:
				settlement.add_stock("Wood", 1)
			state.current_task = "IDLE"
		return

	if state.current_task == "PATROL" or state.current_task == "WANDER":
		var target := _state_position(state.target_position)
		if current.distance_to(target) <= 0.35 or state.behavior_timer >= 8.0:
			state.position = _vector_dict(_ground_position(current))
			state.current_task = "IDLE"
			state.behavior_timer = 0.0
			return
		_move_state_toward(state, target, delta)

func _get_npc_work_target(state: NPCState) -> Vector3:
	var settlement := _settlement_manager()
	if settlement:
		var preferred_types: Array[String] = ["B02_STORAGE", "B05_TOWNHALL", "B01_CAMPFIRE"]
		for building_type in preferred_types:
			for building in settlement.buildings.values():
				if building is Dictionary and str(building.get("type", "")) == building_type:
					var raw_position = building.get("position", [])
					if raw_position is Array and raw_position.size() >= 3:
						return _ground_position(Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2])))
	return _ground_position(_get_settlement_center())

func _move_state_toward(state: NPCState, target: Vector3, delta: float) -> void:
	var current := _state_position(state.position)
	var offset := target - current
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 0.001:
		state.position = _vector_dict(_ground_position(target))
		return
	var step := minf(3.0 * delta, distance)
	var next := _ground_position(current + offset.normalized() * step)
	state.position = _vector_dict(next)
	state.target_position = _vector_dict(target)

func _state_position(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))

func _vector_dict(position: Vector3) -> Dictionary:
	return {"x": position.x, "y": position.y, "z": position.z}


func get_network_snapshot() -> Array:
	var snapshot: Array = []
	for state_value in states.values():
		if state_value is NPCState:
			snapshot.append(state_value.to_dict())
	return snapshot

func apply_network_snapshot(snapshot: Array) -> void:
	var live_ids: Dictionary = {}
	for value in snapshot:
		if not value is Dictionary:
			continue
		var data: Dictionary = value
		var npc_id := str(data.get("npc_id", ""))
		var definition_id := str(data.get("definition_id", "human_villager"))
		if npc_id.is_empty() or not definitions.has(definition_id):
			continue
		live_ids[npc_id] = true
		var state: NPCState = states.get(npc_id)
		if not state:
			var position_data: Dictionary = data.get("position", {})
			var position := Vector3(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)), float(position_data.get("z", 0.0)))
			spawn_npc(npc_id, definition_id, position)
			state = states.get(npc_id)
		if state:
			var restored := NPCState.from_dict(data)
			state.position = restored.position
			state.rotation = restored.rotation
			state.target_position = restored.target_position
			state.health = restored.health
			state.hunger = restored.hunger
			state.thirst = restored.thirst
			state.stamina = restored.stamina
			state.alive = restored.alive
			state.current_job = restored.current_job
			state.current_task = restored.current_task
			state.schedule_state = restored.schedule_state
			state.settlement_id = restored.settlement_id
			state.home_building_id = restored.home_building_id
			state.work_building_id = restored.work_building_id
			state.behavior_timer = restored.behavior_timer
			state.home_position = restored.home_position
	for existing_id in states.keys().duplicate():
		if not live_ids.has(str(existing_id)):
			despawn_npc(str(existing_id))
