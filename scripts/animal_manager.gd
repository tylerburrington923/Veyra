class_name AnimalManager
extends Node3D

const ANIMAL_ACTOR_SCRIPT = preload("res://scripts/animal_actor.gd")
## Lightweight Veyra wildlife runtime.
## Host owns simulation in multiplayer; clients only present authoritative snapshots.
## Creatures use primitive meshes/materials so the build stays small and mobile-friendly.

@export var beta_animal_count: int = 6
@export var spawn_radius: float = 14.0
@export var population_cap: int = 18
@export var reproduction_radius: float = 7.0

var definitions: Dictionary = {}
var states: Dictionary = {}
var _simulation_accumulator := 0.0
const SIMULATION_INTERVAL := 0.10
var visuals: Dictionary = {}
var death_timers: Dictionary = {}
var attack_cooldowns: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _visual_clock: float = 0.0
var _network_snapshot_initialized := false
var _saved_state_loaded := false
var _saved_state: Array = []
var _next_generation_index: int = 1

func _ready() -> void:
	add_to_group("animal_manager")
	_register_definitions()
	call_deferred("_spawn_beta_wildlife")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_simulation_accumulator += minf(delta, 0.25)
	if _simulation_accumulator < SIMULATION_INTERVAL:
		_update_visuals(delta)
		_update_dead_animals(delta)
		return
	var sim_delta := _simulation_accumulator
	_simulation_accumulator = 0.0
	var network := get_node_or_null("/root/NetworkManager")
	if network and bool(network.get("session_active")) and not bool(network.get("is_host")):
		_update_visuals(delta)
		_update_dead_animals(delta)
		return
	for animal_id in states:
		var state: AnimalState = states[animal_id]
		var definition: AnimalDefinition = definitions.get(state.definition_id)
		if state and definition and state.alive:
			state.age_seconds += sim_delta
			state.reproduction_cooldown = maxf(0.0, state.reproduction_cooldown - sim_delta)
			_update_life_stage(state, definition)
			AnimalSimulation.process_tick(state, definition, sim_delta)
			_update_behavior(state, definition, sim_delta)
			if state.age_seconds >= definition.max_age_seconds:
				state.health = 0.0
				state.alive = false
			if not state.alive:
				_on_animal_death(state)
	_process_reproduction()
	_update_dead_animals(delta)
	_update_visuals(delta)


func _register_definitions() -> void:
	# Veyra species deliberately echo Earth silhouettes without copying them.
	definitions["lumen_grazer"] = AnimalDefinition.new(
		"lumen_grazer", "Lumen Grazer", "resonant_cervid",
		1.9, 55.0, 0.020, 0.030, "HERBIVORE"
	)
	definitions["mireback"] = AnimalDefinition.new(
		"mireback", "Mireback", "burrowing_herbivore",
		1.45, 70.0, 0.018, 0.025, "HERBIVORE"
	)
	definitions["veilwolf"] = AnimalDefinition.new(
		"veilwolf", "Veilwolf", "resonant_canid",
		2.6, 45.0, 0.030, 0.045, "PREDATOR"
	)
	definitions["stonebear"] = AnimalDefinition.new(
		"stonebear", "Stonebear", "resonant_ursid",
		1.7, 110.0, 0.014, 0.020, "PREDATOR"
	)

func _spawn_beta_wildlife() -> void:
	if _saved_state_loaded:
		_restore_saved_state()
		return
	var ids: Array[String] = ["lumen_grazer", "mireback", "veilwolf", "lumen_grazer", "stonebear", "veilwolf"]
	var count := mini(beta_animal_count, ids.size())
	for index in range(count):
		var definition_id := ids[index]
		var angle := float(index) * 2.39996323
		var distance := spawn_radius + index * 3.0
		var position := _get_grounded_position(Vector3(cos(angle), 0.0, sin(angle)) * distance)
		spawn_animal("wild_%02d" % (index + 1), definition_id, position)
		var seeded_state: AnimalState = states.get("wild_%02d" % (index + 1))
		if seeded_state:
			seeded_state.sex = "F" if index % 2 == 0 else "M"

func spawn_animal(animal_id: String, definition_id: String, position: Vector3) -> Node3D:
	if animal_id.is_empty() or states.has(animal_id) or not definitions.has(definition_id):
		return null
	var definition: AnimalDefinition = definitions[definition_id]
	var state := AnimalState.new(animal_id, definition_id)
	state.health = definition.max_health
	state.sex = "M" if abs(animal_id.hash()) % 2 == 0 else "F"
	state.generation = 1
	state.age_seconds = 0.0
	state.life_stage = "JUVENILE"
	state.position = _vector_dict(position)
	state.target_position = _vector_dict(position)
	states[animal_id] = state
	var visual := _make_visual(definition_id)
	visual.name = "Animal_" + animal_id
	visual.set_script(ANIMAL_ACTOR_SCRIPT)
	add_child(visual)
	if visual.has_method("configure"):
		visual.configure(self, animal_id)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.25 if definition_id == "lumen_grazer" else 1.0
	collision.shape = capsule
	collision.position.y = 0.65 if definition_id == "lumen_grazer" else 0.45
	visual.add_child(collision)
	if visual is CollisionObject3D:
		(visual as CollisionObject3D).collision_layer = 2
		(visual as CollisionObject3D).collision_mask = 1
		visual.add_to_group("interactable")
	visual.global_position = position
	visuals[animal_id] = visual
	return visual

func set_saved_state(snapshot: Array) -> void:
	_saved_state_loaded = true
	_saved_state.clear()
	for value in snapshot:
		if value is Dictionary:
			_saved_state.append(value.duplicate(true))

func get_save_state() -> Array:
	var snapshot: Array = []
	for state_value in states.values():
		var state: AnimalState = state_value as AnimalState
		if state and state.alive and state.is_valid():
			snapshot.append(state.to_dict())
	return snapshot

func _restore_saved_state() -> void:
	for visual in visuals.values():
		if visual and is_instance_valid(visual):
			visual.queue_free()
	visuals.clear()
	death_timers.clear()
	states.clear()
	for value in _saved_state:
		var data: Dictionary = value if value is Dictionary else {}
		var animal_id := str(data.get("animal_id", ""))
		var definition_id := str(data.get("definition_id", ""))
		if animal_id.is_empty() or not definitions.has(definition_id):
			continue
		var position := _get_grounded_position(_state_position(data.get("position", {})))
		var visual := spawn_animal(animal_id, definition_id, position)
		if visual == null:
			continue
		var restored := AnimalState.from_dict(data)
		restored.position = _vector_dict(position)
		restored.target_position = _vector_dict(_state_position(restored.target_position))
		restored.sanitize()
		if restored.is_valid() and restored.alive:
			states[animal_id] = restored

func _update_life_stage(state: AnimalState, definition: AnimalDefinition) -> void:
	if state.age_seconds < definition.maturity_age_seconds:
		state.life_stage = "JUVENILE"
	elif state.age_seconds < definition.max_age_seconds * 0.75:
		state.life_stage = "ADULT"
	else:
		state.life_stage = "ELDER"

func _process_reproduction() -> void:
	if states.size() >= maxi(1, population_cap):
		return
	var network := get_node_or_null("/root/NetworkManager")
	if network and bool(network.get("session_active")) and not bool(network.get("is_host")):
		return
	var females: Array[AnimalState] = []
	for value in states.values():
		var state: AnimalState = value as AnimalState
		var definition: AnimalDefinition = definitions.get(state.definition_id)
		if state and definition and state.alive and state.sex == "F" and state.life_stage == "ADULT" and state.reproduction_cooldown <= 0.0:
			females.append(state)
	for female in females:
		if states.size() >= maxi(1, population_cap):
			break
		var definition: AnimalDefinition = definitions.get(female.definition_id)
		if not definition:
			continue
		var female_position := _state_position(female.position)
		var mate: AnimalState = null
		for value in states.values():
			var candidate: AnimalState = value as AnimalState
			if candidate == null or candidate == female or not candidate.alive or candidate.definition_id != female.definition_id:
				continue
			if candidate.sex != "M" or candidate.life_stage != "ADULT" or candidate.reproduction_cooldown > 0.0:
				continue
			if female_position.distance_to(_state_position(candidate.position)) <= reproduction_radius:
				mate = candidate
				break
		if mate == null:
			continue
		var midpoint := (female_position + _state_position(mate.position)) * 0.5
		var child_id := "wild_gen_%05d" % _next_generation_index
		_next_generation_index += 1
		var child_visual := spawn_animal(child_id, female.definition_id, _get_grounded_position(midpoint))
		if child_visual == null:
			continue
		var child: AnimalState = states.get(child_id)
		if child:
			child.sex = "M" if abs(child_id.hash()) % 2 == 0 else "F"
			child.generation = maxi(female.generation, mate.generation) + 1
			child.parent_a_id = female.animal_id
			child.parent_b_id = mate.animal_id
			child.life_stage = "JUVENILE"
			child.reproduction_cooldown = definition.reproduction_cooldown_seconds
		female.reproduction_cooldown = definition.reproduction_cooldown_seconds
		mate.reproduction_cooldown = definition.reproduction_cooldown_seconds

func damage_animal(animal_id: String, amount: float, player: Node = null) -> String:
	var state := states.get(animal_id) as AnimalState
	if not state or not state.alive or amount <= 0.0:
		return "It is already down."
	state.health = maxf(0.0, state.health - amount)
	if state.health <= 0.0:
		state.alive = false
		_on_animal_death(state, player)
		return "%s died." % str(definitions[state.definition_id].display_name)
	return "%s • %d HP" % [str(definitions[state.definition_id].display_name), int(ceil(state.health))]

func _on_animal_death(state: AnimalState, player: Node = null) -> void:
	if death_timers.has(state.animal_id):
		return
	death_timers[state.animal_id] = 6.0
	var dead_visual: Node3D = visuals.get(state.animal_id)
	if dead_visual:
		dead_visual.visible = false
		if dead_visual is CollisionObject3D:
			(dead_visual as CollisionObject3D).collision_layer = 0
	var recipient := player
	if not recipient:
		recipient = get_tree().get_first_node_in_group("local_player")
	if recipient and recipient.has_method("get_inventory"):
		var inventory: VeyraInventory = recipient.get_inventory()
		if inventory:
			var definition: AnimalDefinition = definitions.get(state.definition_id)
			if definition:
				var meat_amount := 3 if definition.id == "lumen_grazer" else 4
				var hide_amount := 1 if definition.id == "lumen_grazer" else 2
				var progression := get_node_or_null("/root/ProgressionManager")
				if progression and progression.has_method("has_skill") and progression.has_skill("HUNTSMAN"):
					meat_amount += 1
					hide_amount += 1
				var accepted_meat := inventory.add_resource("Meat", meat_amount)
				var accepted_hide := inventory.add_resource("Hide", hide_amount)
				if progression and progression.has_method("record_action"):
					if accepted_meat > 0:
						progression.record_action("HUNT", accepted_meat, "Meat")
					if accepted_hide > 0:
						progression.record_action("HUNT", accepted_hide, "Hide")

func _update_dead_animals(delta: float) -> void:
	for animal_id in death_timers.keys().duplicate():
		death_timers[animal_id] = float(death_timers[animal_id]) - delta
		if float(death_timers[animal_id]) <= 0.0:
			despawn_animal(str(animal_id))

func despawn_animal(animal_id: String) -> void:
	states.erase(animal_id)
	death_timers.erase(animal_id)
	attack_cooldowns.erase(animal_id)
	var visual: Node3D = visuals.get(animal_id)
	if visual:
		visual.queue_free()
	visuals.erase(animal_id)

func get_network_snapshot() -> Array:
	var snapshot: Array = []
	for animal_id in states:
		var state: AnimalState = states[animal_id]
		if state:
			snapshot.append(state.to_dict())
	return snapshot

func apply_network_snapshot(snapshot: Array) -> void:
	# Unreliable snapshots can arrive before wildlife has spawned on the host.
	# An empty packet must never erase already-present client wildlife.
	if snapshot.is_empty() and not states.is_empty():
		return
	var incoming: Dictionary = {}
	for value in snapshot:
		if not value is Dictionary:
			continue
		var animal_id := str(value.get("animal_id", ""))
		var definition_id := str(value.get("definition_id", ""))
		if animal_id.is_empty() or not definitions.has(definition_id):
			continue
		incoming[animal_id] = value
		var state: AnimalState = states.get(animal_id)
		if not state:
			spawn_animal(animal_id, definition_id, _state_position(value.get("position", {})))
			state = states.get(animal_id)
		if state:
			var restored := AnimalState.from_dict(value)
			restored.sanitize()
			states[animal_id] = restored
			if not visuals.has(animal_id):
				var visual := _make_visual(definition_id)
				visual.name = "Animal_" + animal_id
				visual.set_script(ANIMAL_ACTOR_SCRIPT)
				add_child(visual)
				if visual.has_method("configure"):
					visual.configure(self, animal_id)
				visuals[animal_id] = visual
	for animal_id in states.keys():
		if not incoming.has(animal_id):
			despawn_animal(str(animal_id))

func _update_visuals(delta: float) -> void:
	_visual_clock += delta
	for animal_id in visuals.keys():
		var visual: Node3D = visuals[animal_id]
		var state: AnimalState = states.get(animal_id)
		if not visual or not state:
			continue
		if not state.alive:
			visual.visible = false
			continue
		visual.visible = true
		var target := _state_position(state.position)
		visual.global_position = visual.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
		if state.behavior_state == "WANDER":
			var direction := target - visual.global_position
			direction.y = 0.0
			if direction.length_squared() > 0.01:
				visual.look_at(visual.global_position + direction.normalized(), Vector3.UP)
		var moving := state.behavior_state == "WANDER" or state.behavior_state == "CHASE"
		var gait_speed := 7.5 if state.behavior_state == "CHASE" else 5.0
		for part in visual.get_children():
			if not part is MeshInstance3D:
				continue
			var mesh_part := part as MeshInstance3D
			if bool(mesh_part.get_meta("animal_limb", false)):
				var base_rotation: Vector3 = mesh_part.get_meta("animal_base_rotation", mesh_part.rotation)
				var phase: float = float(mesh_part.get_meta("animal_phase", 0.0))
				var stride := sin(_visual_clock * gait_speed + phase) * (0.32 if moving else 0.04)
				mesh_part.rotation = base_rotation + Vector3(stride, 0.0, 0.0)
			if bool(mesh_part.get_meta("animal_head", false)):
				var base_position: Vector3 = mesh_part.get_meta("animal_base_position", mesh_part.position)
				mesh_part.position = base_position + Vector3(0.0, sin(_visual_clock * gait_speed * 0.5) * (0.025 if moving else 0.008), 0.0)

func _update_behavior(state: AnimalState, definition: AnimalDefinition, delta: float) -> void:
	state.behavior_timer += delta
	if definition.behavior_archetype == "PREDATOR":
		var player := get_tree().get_first_node_in_group("local_player") as Node3D
		if player:
			var current := _state_position(state.position)
			var player_position := player.global_position
			var flat_offset := player_position - current
			flat_offset.y = 0.0
			var player_distance := flat_offset.length()
			if player_distance < 9.0:
				state.behavior_state = "CHASE"
				if player_distance <= 2.0:
					var cooldown := float(attack_cooldowns.get(state.animal_id, 0.0))
					if cooldown <= 0.0 and player.has_method("take_damage") and (not player.has_method("is_alive") or player.is_alive()):
						player.take_damage(10.0 if definition.id == "veilwolf" else 14.0, definition.id)
						attack_cooldowns[state.animal_id] = 1.15
					else:
						attack_cooldowns[state.animal_id] = maxf(0.0, cooldown - delta)
					return
				if player_distance > 2.0:
					var step := minf(definition.movement_speed * delta, player_distance)
					state.position = _vector_dict(_get_grounded_position(current + flat_offset.normalized() * step))
					return
				state.behavior_state = "IDLE"
				return
			if state.behavior_state == "CHASE":
				attack_cooldowns[state.animal_id] = 0.0
				state.behavior_state = "IDLE"
				state.behavior_timer = 0.0
	if state.behavior_state == "IDLE":
		if state.behavior_timer >= 4.0 + float(abs(state.animal_id.hash()) % 4):
			state.behavior_timer = 0.0
			var origin := _state_position(state.position)
			var phase := float(abs(state.animal_id.hash()) % 360) * 0.0174533
			var target := origin + Vector3(cos(phase), 0.0, sin(phase)) * (4.0 if definition.id == "lumen_grazer" else 3.2)
			state.target_position = _vector_dict(_get_grounded_position(target))
			state.behavior_state = "WANDER"
		return
	if state.behavior_state == "WANDER":
		var current := _state_position(state.position)
		var target := _state_position(state.target_position)
		var offset := target - current
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.35 or state.behavior_timer >= 8.0:
			state.position = _vector_dict(_get_grounded_position(current))
			state.behavior_state = "IDLE"
			state.behavior_timer = 0.0
			return
		var step := minf(definition.movement_speed * delta, distance)
		state.position = _vector_dict(_get_grounded_position(current + offset.normalized() * step))
		state.stamina = clampf(state.stamina - 0.08 * delta, 0.0, 100.0)

func _make_visual(definition_id: String) -> StaticBody3D:
	if definition_id == "mireback":
		return _make_mireback_visual()
	if definition_id == "veilwolf":
		return _make_veilwolf_visual()
	if definition_id == "stonebear":
		return _make_stonebear_visual()
	return _make_lumen_grazer_visual()

func _make_lumen_grazer_visual() -> StaticBody3D:
	var root := StaticBody3D.new()
	root.add_to_group("animal")
	root.set_meta("animal_manager", self)
	var coat := _material(Color(0.24, 0.34, 0.29), 0.92)
	var glow := _material(Color(0.12, 0.60, 0.58), 0.7, 0.0, true, 0.75)
	var dark := _material(Color(0.08, 0.10, 0.09), 1.0)

	_add_capsule(root, Vector3(0, 0.88, 0), Vector3(0.25, 0.24, 0.52), coat, 7, 0, 90)
	_add_sphere(root, Vector3(0.58, 1.05, 0), 0.22, coat, 7)
	for side in [-1.0, 1.0]:
		for x in [-0.28, 0.28]:
			_add_capsule(root, Vector3(x, 0.44, side * 0.15), Vector3(0.06, 0.08, 0.36), dark, 5)
	_add_sphere(root, Vector3(-0.54, 1.02, 0), 0.10, dark, 5)
	_add_sphere(root, Vector3(0.58, 1.13, -0.19), 0.055, glow, 5)
	_add_sphere(root, Vector3(0.58, 1.13, 0.19), 0.055, glow, 5)
	# Short resonance antlers are intentionally asymmetrical.
	_add_cylinder(root, Vector3(0.42, 1.32, -0.12), 0.035, 0.34, glow, 5, Vector3(0.0, 0.0, deg_to_rad(-25.0)))
	_add_cylinder(root, Vector3(0.42, 1.34, 0.12), 0.035, 0.28, glow, 5, Vector3(0.0, 0.0, deg_to_rad(18.0)))
	return root

func _make_veilwolf_visual() -> StaticBody3D:
	var root := StaticBody3D.new()
	root.add_to_group("animal")
	root.set_meta("animal_manager", self)
	var coat := _material(Color(0.12, 0.15, 0.17), 0.95)
	var muzzle := _material(Color(0.20, 0.23, 0.24), 0.92)
	var glow := _material(Color(0.32, 0.78, 0.76), 0.55, 0.0, true, 0.9)
	_add_capsule(root, Vector3(0, 0.62, 0), Vector3(0.22, 0.22, 0.46), coat, 7, 0, 90)
	_add_sphere(root, Vector3(0.50, 0.72, 0), 0.20, coat, 7)
	_add_sphere(root, Vector3(0.67, 0.68, 0), 0.12, muzzle, 6, Vector3(1.15, 0.75, 0.8))
	for side in [-1.0, 1.0]:
		for x in [-0.25, 0.25]:
			_add_capsule(root, Vector3(x, 0.30, side * 0.13), Vector3(0.055, 0.06, 0.28), coat, 5)
	_add_sphere(root, Vector3(0.55, 0.80, -0.14), 0.045, glow, 5)
	_add_sphere(root, Vector3(0.55, 0.80, 0.14), 0.045, glow, 5)
	_add_sphere(root, Vector3(-0.48, 0.68, 0), 0.11, coat, 6, Vector3(1.4, 0.7, 0.7))
	return root

func _make_stonebear_visual() -> StaticBody3D:
	var root := StaticBody3D.new()
	root.add_to_group("animal")
	root.set_meta("animal_manager", self)
	var coat := _material(Color(0.26, 0.24, 0.21), 0.96)
	var chest := _material(Color(0.34, 0.31, 0.27), 0.94)
	var glow := _material(Color(0.20, 0.58, 0.55), 0.65, 0.0, true, 0.55)
	_add_capsule(root, Vector3(0, 0.82, 0), Vector3(0.34, 0.34, 0.58), coat, 7, 0, 90)
	_add_sphere(root, Vector3(0.52, 0.94, 0), 0.29, coat, 7)
	_add_sphere(root, Vector3(0.66, 0.88, 0), 0.16, chest, 6, Vector3(1.15, 0.8, 0.9))
	for side in [-1.0, 1.0]:
		for x in [-0.30, 0.30]:
			_add_capsule(root, Vector3(x, 0.40, side * 0.21), Vector3(0.09, 0.10, 0.38), coat, 5)
	_add_sphere(root, Vector3(0.58, 1.10, -0.19), 0.045, glow, 5)
	_add_sphere(root, Vector3(0.58, 1.10, 0.19), 0.045, glow, 5)
	return root

func _make_mireback_visual() -> StaticBody3D:
	var root := StaticBody3D.new()
	root.add_to_group("animal")
	root.set_meta("animal_manager", self)
	var hide := _material(Color(0.20, 0.17, 0.13), 0.96)
	var ridge := _material(Color(0.22, 0.45, 0.40), 0.72, 0.0, true, 0.55)
	var dark := _material(Color(0.07, 0.065, 0.055), 1.0)
	_add_capsule(root, Vector3(0, 0.66, 0), Vector3(0.34, 0.30, 0.60), hide, 7, 0, 90)
	_add_sphere(root, Vector3(0.62, 0.70, 0), 0.25, hide, 7)
	for x in [-0.28, 0.28]:
		for side in [-1.0, 1.0]:
			_add_capsule(root, Vector3(x, 0.29, side * 0.20), Vector3(0.075, 0.08, 0.30), dark, 5)
	for x in [-0.38, -0.12, 0.14, 0.40]:
		_add_sphere(root, Vector3(x, 1.00 - abs(x) * 0.18, 0), 0.12, ridge, 6, Vector3(0.8, 1.2, 0.8))
	_add_sphere(root, Vector3(0.67, 0.76, -0.20), 0.055, ridge, 5)
	_add_sphere(root, Vector3(0.67, 0.76, 0.20), 0.055, ridge, 5)
	root.set_meta("animal_id", "")
	return root

func _material(color: Color, roughness: float = 0.9, metallic: float = 0.0, emission_enabled: bool = false, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_enabled:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material

func _add_capsule(root: Node3D, position_value: Vector3, dimensions: Vector3, material: Material, segments: int, _unused: int = 0, rotation_z: float = 0.0) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = dimensions.x
	mesh.height = dimensions.y + dimensions.z
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.rotation_degrees.z = rotation_z
	if position_value.y < 0.6:
		instance.set_meta("animal_limb", true)
		instance.set_meta("animal_base_rotation", instance.rotation)
		instance.set_meta("animal_phase", 0.0 if position_value.z < 0.0 else PI)
	root.add_child(instance)

func _add_sphere(root: Node3D, position_value: Vector3, radius: float, material: Material, segments: int = 7, scale_value := Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 4
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.scale = scale_value
	if position_value.x > 0.35 and position_value.y > 0.55:
		instance.set_meta("animal_head", true)
		instance.set_meta("animal_base_position", position_value)
	root.add_child(instance)

func _add_cylinder(root: Node3D, position_value: Vector3, radius: float, height: float, material: Material, segments: int, rotation_value: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.rotation = rotation_value
	root.add_child(instance)

func _get_grounded_position(position: Vector3) -> Vector3:
	var generator := get_tree().get_first_node_in_group("world_generator")
	if generator and generator.has_method("get_height_at_world"):
		position.y = float(generator.get_height_at_world(position.x, position.z))
	return position + Vector3(0.0, 0.05, 0.0)

func _state_position(data: Variant) -> Vector3:
	var value: Dictionary = data if data is Dictionary else {}
	return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))

func _vector_dict(position: Vector3) -> Dictionary:
	return {"x": position.x, "y": position.y, "z": position.z}
