extends Node3D

@export var seed_value := 47291
@export var count := 70
@export var radius := 85.0

func _ready() -> void:
    _generate()

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

    for i in range(count):
        var angle := rng.randf_range(0.0, TAU)
        var distance := sqrt(rng.randf()) * radius
        var x := cos(angle) * distance
        var z := sin(angle) * distance
        if Vector2(x, z).length() < 12.0:
            continue

        var tree := Node3D.new()
        tree.position = Vector3(x, 0, z)

        var trunk := MeshInstance3D.new()
        trunk.mesh = trunk_mesh
        trunk.position.y = 0.75
        trunk.material_override = _trunk_material()
        tree.add_child(trunk)

        var leaves := MeshInstance3D.new()
        leaves.mesh = leaf_mesh
        leaves.position.y = rng.randf_range(1.6, 2.3)
        leaves.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
        leaves.material_override = _leaf_material(i)
        tree.add_child(leaves)
        add_child(tree)

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
