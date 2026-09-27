class_name AnimalManager
extends Node3D

## Lightweight Veyra wildlife runtime.
## Host owns simulation in multiplayer; clients only present authoritative snapshots.
## Creatures use primitive meshes/materials so the build stays small and mobile-friendly.

@export var beta_animal_count: int = 5
@export var spawn_radius: float = 18.0

var definitions: Dictionary = {}
var states: Dictionary = {}
var visuals: Dictionary = {}
var death_timers: Dictionary = {}

func _ready() -> void:
	add_to_group("animal_manager")
	_register_definitions()
	call_deferred("_spawn_beta_wildlife")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var network := get_node_or_null("/root/NetworkManager")
	if network and bool(network.get("session_active")) and not bool(network.get("is_host")):
		_update_visuals(delta)
		return
	for animal_id in states:
		var state: AnimalState = states[animal_id]
		var definition: AnimalDefinition = definitions.get(state.definition_id)
		if state and definition and state.alive:
			AnimalSimulation.process_tick(state, definition, delta)
			_update_behavior(state, definition, delta)
			if not state.alive:
				_on_animal_death(state)
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

func _spawn_beta_wildlife() -> void:
	var ids: Array[String] = ["lumen_grazer", "mireback", "lumen_grazer", "mireback", "lumen_grazer"]
	var count := mini(beta_animal_count, ids.size())
	for index in range(count):
		var definition_id := ids[index]
		var angle := float(index) * 2.39996323
		var distance := spawn_radius + index * 3.0
		var position := _get_grounded_position(Vector3(cos(angle), 0.0, sin(angle)) * distance)
		spawn_animal("wild_%02d" % (index + 1), definition_id, position)

func spawn_animal(animal_id: String, definition_id: String, position: Vector3) -> Node3D:
	if animal_id.is_empty() or states.has(animal_id) or not definitions.has(definition_id):
		return null
	var definition: AnimalDefinition = definitions[definition_id]
	var state := AnimalState.new(animal_id, definition_id)
	state.health = definition.max_health
	state.position = _vector_dict(position)
	state.target_position = _vector_dict(position)
	states[animal_id] = state
	var visual := _make_visual(definition_id)
	visual.name = "Animal_" + animal_id
	add_child(visual)
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
	var recipient := player
	if not recipient:
		recipient = get_tree().get_first_node_in_group("local_player")
	if recipient and recipient.has_method("get_inventory"):
		var inventory: VeyraInventory = recipient.get_inventory()
		if inventory:
			var definition: AnimalDefinition = definitions.get(state.definition_id)
			var drop_type := "Wood" if definition and definition.id == "mireback" else "Stone"
			inventory.add_resource(drop_type, 2)

func _update_dead_animals(delta: float) -> void:
	for animal_id in death_timers.keys().duplicate():
		death_timers[animal_id] = float(death_timers[animal_id]) - delta
		if float(death_timers[animal_id]) <= 0.0:
			despawn_animal(str(animal_id))

func despawn_animal(animal_id: String) -> void:
	states.erase(animal_id)
	death_timers.erase(animal_id)
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
				add_child(visual)
				visuals[animal_id] = visual
	for animal_id in states.keys():
		if not incoming.has(animal_id):
			despawn_animal(str(animal_id))

func _update_visuals(delta: float) -> void:
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

func _update_behavior(state: AnimalState, definition: AnimalDefinition, delta: float) -> void:
	state.behavior_timer += delta
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
