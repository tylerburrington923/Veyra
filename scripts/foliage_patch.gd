extends Node3D

## Decorative foliage optimized for mobile.
## Trees use MultiMesh instancing while individual resource nodes own harvest state.
## Harvest state drives both rendered instances and their movement collision.

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

    var trunk_instances := _create_multimesh("TreeTrunks", trunk_mesh, trunk_material, trunk_transforms)
    var leaf_instances := _create_multimesh("TreeCanopies", leaf_mesh, leaf_material, leaf_transforms)
    var tree_collisions := _create_tree_collision(trunk_transforms)
    _create_tree_harvest_nodes(trunk_transforms, trunk_instances, leaf_instances, tree_collisions)


func _create_tree_harvest_nodes(
    transforms: Array[Transform3D],
    trunk_instances: MultiMeshInstance3D,
    leaf_instances: MultiMeshInstance3D,
    tree_collisions: StaticBody3D
) -> void:
    if not terrain or transforms.is_empty():
        return

    var saved_state: Dictionary = terrain.saved_resource_state
    for i in range(transforms.size()):
        var node := preload("res://scenes/resource_node.tscn").instantiate()
        node.resource_id = "D01-TREE-%03d" % (i + 1)
        node.name = node.resource_id
        node.resource_type = "Wood"
        node.tool_required = "I01_STONE_AXE"
        node.amount = 4
        node.durability_cost = 1.0
        node.physical_collision = false
        node.global_transform = transforms[i]

        var collision := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = 0.28
        shape.height = 1.7
        collision.shape = shape
        node.add_child(collision)
        terrain.add_child(node)

        var visual_index := i
        var trunk_transform := transforms[i]
        var leaf_transform := transforms[i]
        # The canopy transform has a different Y position, so retain its actual
        # MultiMesh transform rather than reusing the trunk transform.
        if leaf_instances and leaf_instances.multimesh:
            leaf_transform = leaf_instances.multimesh.get_instance_transform(i)

        var tree_collision: CollisionShape3D = null
        if tree_collisions and i < tree_collisions.get_child_count():
            tree_collision = tree_collisions.get_child(i) as CollisionShape3D

        if trunk_instances or leaf_instances or tree_collision:
            node.set_visual_controller(func(active: bool) -> void:
                _set_tree_visual(
                    trunk_instances,
                    leaf_instances,
                    tree_collision,
                    visual_index,
                    trunk_transform,
                    leaf_transform,
                    active
                )
            )

        if saved_state.has(node.resource_id):
            node.apply_save_state(saved_state[node.resource_id])


func _set_tree_visual(
    trunk_instances: MultiMeshInstance3D,
    leaf_instances: MultiMeshInstance3D,
    tree_collision: CollisionShape3D,
    index: int,
    trunk_transform: Transform3D,
    leaf_transform: Transform3D,
    active: bool
) -> void:
    if is_instance_valid(trunk_instances) and trunk_instances.multimesh:
        trunk_instances.multimesh.set_instance_transform(
            index,
            trunk_transform if active else _hidden_transform(trunk_transform)
        )
    if is_instance_valid(leaf_instances) and leaf_instances.multimesh:
        leaf_instances.multimesh.set_instance_transform(
            index,
            leaf_transform if active else _hidden_transform(leaf_transform)
        )
    if is_instance_valid(tree_collision):
        tree_collision.disabled = not active


func _hidden_transform(original: Transform3D) -> Transform3D:
    var hidden := original
    hidden.origin.y -= 10000.0
    return hidden


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


func _create_tree_collision(transforms: Array[Transform3D]) -> StaticBody3D:
    if transforms.is_empty():
        return null
    collision_body = StaticBody3D.new()
    collision_body.name = "TreeCollision"
    collision_body.collision_layer = 2
    collision_body.collision_mask = 1
    add_child(collision_body)
    for tree_transform in transforms:
        var collision := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = 0.16
        shape.height = 1.5
        collision.shape = shape
        collision.transform = tree_transform
        collision_body.add_child(collision)
    return collision_body
