extends Node3D

## Decorative foliage optimized for mobile.
## Trees are rendered with two MultiMeshes instead of one Node3D per tree.

@export var seed_value: int = 47291
@export var count: int = 70
@export var radius: float = 85.0
@export var exclusion_radius: float = 12.0

var terrain: Node
var collision_body: StaticBody3D


func _ready() -> void:
	terrain = get_parent().get_node_or_null("WorldGenerator")
	call_deferred("_generate")


func _generate() -> void:
	if count <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7001

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.08
	trunk_mesh.bottom_radius = 0.13
	trunk_mesh.height = 1.5
	trunk_mesh.radial_segments = 5

	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.65
	leaf_mesh.height = 1.15
	leaf_mesh.radial_segments = 6
	leaf_mesh.rings = 3

	var trunk_material := _trunk_material()
	var leaf_material := _leaf_material()

	var trunk_transforms: Array[Transform3D] = []
	var leaf_transforms: Array[Transform3D] = []

	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = sqrt(rng.randf()) * radius
		var x: float = cos(angle) * distance
		var z: float = sin(angle) * distance

		if Vector2(x, z).length() < exclusion_radius:
			continue

		var ground_y: float = _ground_height(x, z)
		var tree_scale: float = rng.randf_range(0.8, 1.25)
		var yaw: float = rng.randf_range(0.0, TAU)

		var tree_basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * tree_scale)

		trunk_transforms.append(
			Transform3D(
				tree_basis,
				Vector3(x, ground_y + 0.75 * tree_scale, z)
			)
		)

		var leaf_y: float = rng.randf_range(1.6, 2.3) * tree_scale
		leaf_transforms.append(
			Transform3D(
				tree_basis,
				Vector3(x, ground_y + leaf_y, z)
			)
		)

	_create_multimesh("TreeTrunks", trunk_mesh, trunk_material, trunk_transforms)
	_create_multimesh("TreeCanopies", leaf_mesh, leaf_material, leaf_transforms)
	_create_tree_collision(trunk_transforms)


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


func _trunk_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.20, 0.13, 1)
	material.roughness = 1.0
	return material


func _leaf_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.39, 0.26, 1)
	material.roughness = 1.0
	return material


func _create_tree_collision(transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	collision_body = StaticBody3D.new()
	collision_body.name = "TreeCollision"
	collision_body.collision_layer = 2
	collision_body.collision_mask = 1
	add_child(collision_body)
	var shape := CylinderShape3D.new()
	shape.radius = 0.16
	shape.height = 1.5
	for tree_transform in transforms:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = tree_transform
		collision_body.add_child(collision)
