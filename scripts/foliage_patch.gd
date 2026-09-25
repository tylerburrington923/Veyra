extends Node3D

@export var seed_value := 47291
@export var count := 70
@export var radius := 85.0

var terrain: Node

func _ready() -> void:
    terrain = get_parent().get_node_or_null("WorldGenerator")
    call_deferred("_generate")

func _generate() -> void:
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
    var leaf_materials: Array[StandardMaterial3D] = []
    for i in range(5):
        leaf_materials.append(_leaf_material(i))

    for i in range(count):
        var angle := rng.randf_range(0.0, TAU)
        var distance := sqrt(rng.randf()) * radius
        var x := cos(angle) * distance
        var z := sin(angle) * distance
        if Vector2(x, z).length() < 12.0:
            continue

        var tree := Node3D.new()
        tree.position = Vector3(x, _ground_height(x, z), z)

        var trunk := MeshInstance3D.new()
        trunk.mesh = trunk_mesh
        trunk.position.y = 0.75
        trunk.material_override = trunk_material
        tree.add_child(trunk)

        var leaves := MeshInstance3D.new()
        leaves.mesh = leaf_mesh
        leaves.position.y = rng.randf_range(1.6, 2.3)
        leaves.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
        leaves.material_override = leaf_materials[i % leaf_materials.size()]
        tree.add_child(leaves)
        add_child(tree)

func _ground_height(x: float, z: float) -> float:
    if terrain and terrain.has_method("get_height_at_world"):
        return terrain.get_height_at_world(x, z)
    return 0.0

func _trunk_material() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.25, 0.20, 0.13, 1)
    m.roughness = 1.0
    return m

func _leaf_material(index: int) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    var v := float(index % 5) * 0.018
    m.albedo_color = Color(0.20 + v, 0.34 + v, 0.22 + v, 1)
    m.roughness = 1.0
    return m
