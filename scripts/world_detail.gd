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
				basis,
				Vector3(x, ground_y + 0.25, z)
			)
		)

	_create_multimesh("Rocks", rock_mesh, rock_material, rock_transforms)
	_create_rock_collision(rock_transforms)

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
				basis,
				Vector3(x, ground_y + 0.8 * scale, z)
			)
		)

	_create_multimesh(
		"Minerals",
		crystal_mesh,
		crystal_material,
		crystal_transforms
	)

	_create_crystal_collision(crystal_transforms)

	_make_water()


func _create_multimesh(
	node_name: String,
	mesh: Mesh,
	material: StandardMaterial3D,
	transforms: Array[Transform3D]
) -> void:
	if transforms.is_empty():
		return

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


func _ground_height(x: float, z: float) -> float:
	if terrain and terrain.has_method("get_height_at_world"):
		return terrain.get_height_at_world(x, z)
	return 0.0


func _make_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(32, 20)
	mesh.subdivide_width = 2
	mesh.subdivide_depth = 2
	water.mesh = mesh
	water.position = Vector3(
		28.0,
		_ground_height(28.0, 18.0) - 0.25,
		18.0
	)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.25, 0.29, 0.72)
	material.metallic = 0.05
	material.roughness = 0.22
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = material

	add_child(water)


func _create_rock_collision(transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	collision_body = StaticBody3D.new()
	collision_body.name = "RockCollision"
	collision_body.collision_layer = 2
	collision_body.collision_mask = 1
	add_child(collision_body)
	var shape := SphereShape3D.new()
	shape.radius = 0.48
	for rock_transform in transforms:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = rock_transform
		collision_body.add_child(collision)

func _create_crystal_collision(transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "MineralCollision"
	body.collision_layer = 2
	body.collision_mask = 1
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.65, 1.6, 0.65)
	for crystal_transform in transforms:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = crystal_transform
		body.add_child(collision)
