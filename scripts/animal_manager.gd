class_name AnimalManager
extends Node3D

## Lightweight wildlife presentation bridge. AnimalState remains authoritative;
## this manager owns runtime states and disposable presentation nodes.

@export var beta_animal_count: int = 3
@export var spawn_radius: float = 18.0

var definitions: Dictionary = {}
var states: Dictionary = {}
var visuals: Dictionary = {}

func _ready() -> void:
	add_to_group("animal_manager")
	_register_definitions()
	call_deferred("_spawn_beta_wildlife")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	for animal_id in states:
		var state: AnimalState = states[animal_id]
		var definition: AnimalDefinition = definitions.get(state.definition_id)
		if state and definition:
			AnimalSimulation.process_tick(state, definition, delta)
			_update_behavior(state, definition, delta)
	for animal_id in visuals:
		var visual: Node3D = visuals[animal_id]
		var state: AnimalState = states.get(animal_id)
		if visual and state:
			var target := _state_position(state.position)
			visual.global_position = visual.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
			if state.behavior_state == "WANDER":
				var direction := target - visual.global_position
				direction.y = 0.0
				if direction.length_squared() > 0.01:
					visual.look_at(visual.global_position + direction.normalized(), Vector3.UP)

func _register_definitions() -> void:
	definitions["deer"] = AnimalDefinition.new("deer", "Forest Deer", "cervid", 1.8, 50.0, 0.025, 0.035, "HERBIVORE")

func _spawn_beta_wildlife() -> void:
	var definition: AnimalDefinition = definitions["deer"]
	for index in range(beta_animal_count):
		var angle := float(index) * 2.39996323
		var position := _get_grounded_position(Vector3(cos(angle), 0.0, sin(angle)) * (spawn_radius + index * 3.0))
		spawn_animal("deer_%02d" % (index + 1), definition.id, position)

func spawn_animal(animal_id: String, definition_id: String, position: Vector3) -> Node3D:
	if animal_id.is_empty() or states.has(animal_id) or not definitions.has(definition_id):
		return null
	var definition: AnimalDefinition = definitions[definition_id]
	var state := AnimalState.new(animal_id, definition_id)
	state.health = definition.max_health
	state.position = _vector_dict(position)
	state.target_position = _vector_dict(position)
	states[animal_id] = state

	var visual := _make_deer_visual(definition)
	visual.name = "Animal_" + animal_id
	add_child(visual)
	visual.global_position = position
	visuals[animal_id] = visual
	return visual

func despawn_animal(animal_id: String) -> void:
	states.erase(animal_id)
	var visual: Node3D = visuals.get(animal_id)
	if visual:
		visual.queue_free()
	visuals.erase(animal_id)

func _update_behavior(state: AnimalState, definition: AnimalDefinition, delta: float) -> void:
	state.behavior_timer += delta
	if state.behavior_state == "IDLE":
		if state.behavior_timer >= 4.0 + float(abs(state.animal_id.hash()) % 4):
			state.behavior_timer = 0.0
			var origin := _state_position(state.position)
			var phase := float(abs(state.animal_id.hash()) % 360) * 0.0174533
			var target := origin + Vector3(cos(phase), 0.0, sin(phase)) * 5.0
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
		var next := _get_grounded_position(current + offset.normalized() * step)
		state.position = _vector_dict(next)
		state.stamina = clampf(state.stamina - 0.08 * delta, 0.0, 100.0)

func _make_deer_visual(definition: AnimalDefinition) -> Node3D:
	var root := Node3D.new()
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.38, 0.25, 0.14, 1)
	coat.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.065, 0.045, 1)
	dark.roughness = 1.0

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.22
	body_mesh.height = 0.95
	body_mesh.radial_segments = 7
	body.mesh = body_mesh
	body.material_override = coat
	body.rotation_degrees.z = 90.0
	body.position.y = 0.85
	root.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.20
	head_mesh.height = 0.40
	head_mesh.radial_segments = 7
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.material_override = coat
	head.position = Vector3(0.52, 1.0, 0.0)
	root.add_child(head)

	for side in [-1.0, 1.0]:
		for leg_index in range(2):
			var leg := MeshInstance3D.new()
			var leg_mesh := CapsuleMesh.new()
			leg_mesh.radius = 0.055
			leg_mesh.height = 0.48
			leg_mesh.radial_segments = 5
			leg.mesh = leg_mesh
			leg.material_override = dark
			leg.position = Vector3(-0.25 + leg_index * 0.5, 0.38, side * 0.13)
			root.add_child(leg)

	var tail := MeshInstance3D.new()
	var tail_mesh := SphereMesh.new()
	tail_mesh.radius = 0.09
	tail_mesh.height = 0.18
	tail_mesh.radial_segments = 5
	tail_mesh.rings = 3
	tail.mesh = tail_mesh
	tail.material_override = dark
	tail.position = Vector3(-0.53, 1.0, 0.0)
	root.add_child(tail)

	return root

func _get_grounded_position(position: Vector3) -> Vector3:
	var generator := get_tree().get_first_node_in_group("world_generator")
	if generator and generator.has_method("get_height_at_world"):
		position.y = float(generator.get_height_at_world(position.x, position.z))
	return position + Vector3(0.0, 0.05, 0.0)

func _state_position(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))

func _vector_dict(position: Vector3) -> Dictionary:
	return {"x": position.x, "y": position.y, "z": position.z}
