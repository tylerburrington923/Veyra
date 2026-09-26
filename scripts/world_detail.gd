extends Node3D

## Cheap environmental detail pass optimized for mobile.
## Rocks and minerals use MultiMesh instancing; water remains a single mesh.

@export var seed_value: int = 47291
@export var rock_count: int = 55
@export var mineral_count: int = 18
@export var world_radius: float = 85.0

var terrain: Node
var collision_body: StaticBody3D


func _ready() -> void:
	terrain = get_parent().get_node_or_null("WorldGenerator")
	call_deferred("_generate")


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 300

	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.55
	rock_mesh.height = 0.85
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3

	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.30, 0.32, 0.30, 1)
	rock_material.roughness = 1.0

	var rock_transforms: Array[Transform3D] = []

	for i in range(rock_count):
		var x := rng.randf_range(-world_radius, world_radius)
		var z := rng.randf_range(-world_radius, world_radius)
		var ground_y := _ground_height(x, z)

		var rock_basis := Basis(
			Vector3.UP,
			rng.randf_range(0.0, TAU)
		).scaled(
			Vector3(
				rng.randf_range(0.6, 1.8),
				rng.randf_range(0.45, 1.0),
				rng.randf_range(0.6, 1.5)
			)
		)

		rock_transforms.append(
			Transform3D(
				rock_basis,
				Vector3(x, ground_y + 0.25, z)
			)
		)

	var rock_instances := _create_multimesh("Rocks", rock_mesh, rock_material, rock_transforms)
	_create_harvest_nodes("SMALL_STONE", rock_transforms, "Stone", "T00_HANDS", 1, 0.0, rock_instances)

	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(0.65, 1.6, 0.65)

	var crystal_material := StandardMaterial3D.new()
	crystal_material.albedo_color = Color(0.30, 0.18, 0.42, 1)
	crystal_material.emission_enabled = true
	crystal_material.emission = Color(0.08, 0.03, 0.14, 1)
	crystal_material.emission_energy_multiplier = 0.45

	var crystal_transforms: Array[Transform3D] = []

	for i in range(mineral_count):
		var x := rng.randf_range(-world_radius * 0.82, world_radius * 0.82)
		var z := rng.randf_range(-world_radius * 0.82, world_radius * 0.82)
		var ground_y := _ground_height(x, z)
		var crystal_scale := rng.randf_range(0.5, 1.2)

		var crystal_basis := Basis(
			Vector3.UP,
			rng.randf_range(0.0, TAU)
		).scaled(Vector3.ONE * crystal_scale)

		crystal_transforms.append(
			Transform3D(
				crystal_basis,
				Vector3(x, ground_y + 0.8 * crystal_scale, z)
			)
		)

	var crystal_instances := _create_multimesh(
		"Minerals",
		crystal_mesh,
		crystal_material,
		crystal_transforms
	)
	_create_harvest_nodes("PURPLE_LUX", crystal_transforms, "Vitreous Lux", "I02_STONE_PICK", 1, 1.0, crystal_instances)


	_make_water()


func _create_harvest_nodes(prefix: String, transforms: Array[Transform3D], resource_type: String, required_tool: String, amount: int, durability_cost: float, visual_instance: MultiMeshInstance3D) -> void:
	if not terrain or transforms.is_empty():
		return
	for i in range(transforms.size()):
		var node := preload("res://scenes/resource_node.tscn").instantiate()
		node.resource_id = "D01-%s-%03d" % [prefix, i + 1]
		node.name = node.resource_id
		node.resource_type = resource_type
		node.tool_required = required_tool
		node.amount = amount
		node.durability_cost = durability_cost
		node.physical_collision = true
		node.global_transform = transforms[i]
		var collision := CollisionShape3D.new()
		var shape: Shape3D
		if prefix == "TREE":
			shape = CylinderShape3D.new()
			shape.radius = 0.16
			shape.height = 1.5
		else:
			shape = SphereShape3D.new()
			shape.radius = 0.48
		collision.shape = shape
		node.add_child(collision)
		terrain.add_child(node)
		var original_transform := transforms[i]
		var visual_index := i
		if visual_instance:
			node.set_visual_controller(func(active: bool) -> void:
				_set_harvest_visual(visual_instance, visual_index, original_transform, active)
			)
		var saved_state: Dictionary = terrain.saved_resource_state
		if saved_state.has(node.resource_id):
			node.apply_save_state(saved_state[node.resource_id])


func _set_harvest_visual(instance: MultiMeshInstance3D, index: int, original_transform: Transform3D, active: bool) -> void:
	if not is_instance_valid(instance) or instance.multimesh == null:
		return
	if active:
		instance.multimesh.set_instance_transform(index, original_transform)
	else:
		instance.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), original_transform.origin))

func _create_multimesh(
	node_name: String,
	mesh: Mesh,
	material: StandardMaterial3D,
	transforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)
	return instance


func _ground_height(x: float, z: float) -> float:
	if terrain and terrain.has_method("get_height_at_world"):
		return terrain.get_height_at_world(x, z)
	return 0.0


func _make_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(32, 20)
	mesh.subdivide_width = 12
	mesh.subdivide_depth = 8
	water.mesh = mesh
	water.position = Vector3(
		28.0,
		_ground_height(28.0, 18.0) - 0.25,
		18.0
	)

	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.035, 0.20, 0.24, 0.88);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.42, 0.45, 0.82);

void vertex() {
	float wave_a = sin(VERTEX.x * 0.55 + TIME * 0.9) * 0.055;
	float wave_b = cos(VERTEX.z * 0.72 + TIME * 0.65) * 0.04;
	VERTEX.y += wave_a + wave_b;
}

void fragment() {
	float wave = 0.5 + 0.5 * sin(UV.x * 18.0 + UV.y * 9.0 + TIME * 0.7);
	vec3 surface = mix(deep_color.rgb, shallow_color.rgb, wave * 0.28);
	float edge = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.0);
	ALBEDO = mix(surface, vec3(0.55, 0.80, 0.78), edge * 0.18);
	ROUGHNESS = 0.16;
	METALLIC = 0.05;
	ALPHA = mix(deep_color.a, shallow_color.a, wave * 0.2);
}
"""
	material.shader = shader
	water.material_override = material

	add_child(water)


