extends Node3D

## Cheap environmental detail pass: rocks, mineral clusters, and one shallow
## water plane. Decorative objects have no physics unless explicitly needed.

@export var seed_value := 47291
@export var rock_count := 55
@export var mineral_count := 18

var terrain: Node

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

    for i in range(rock_count):
        var rock := MeshInstance3D.new()
        rock.mesh = rock_mesh
        rock.material_override = rock_material
        var x := rng.randf_range(-85.0, 85.0)
        var z := rng.randf_range(-85.0, 85.0)
        rock.position = Vector3(x, _ground_height(x, z) + 0.25, z)
        rock.scale = Vector3(
            rng.randf_range(0.6, 1.8),
            rng.randf_range(0.45, 1.0),
            rng.randf_range(0.6, 1.5)
        )
        add_child(rock)

    var crystal_mesh := PrismMesh.new()
    crystal_mesh.size = Vector3(0.65, 1.6, 0.65)

    var crystal_material := StandardMaterial3D.new()
    crystal_material.albedo_color = Color(0.30, 0.18, 0.42, 1)
    crystal_material.emission_enabled = true
    crystal_material.emission = Color(0.08, 0.03, 0.14, 1)
    crystal_material.emission_energy_multiplier = 0.45

    for i in range(mineral_count):
        var crystal := MeshInstance3D.new()
        crystal.mesh = crystal_mesh
        crystal.material_override = crystal_material
        var x := rng.randf_range(-70.0, 70.0)
        var z := rng.randf_range(-70.0, 70.0)
        crystal.position = Vector3(x, _ground_height(x, z) + 0.8, z)
        crystal.rotation_degrees.y = rng.randf_range(0.0, 360.0)
        crystal.scale = Vector3.ONE * rng.randf_range(0.5, 1.2)
        add_child(crystal)

    _make_water()

func _ground_height(x: float, z: float) -> float:
    if terrain and terrain.has_method("get_height_at_world"):
        return terrain.get_height_at_world(x, z)
    return 0.0

func _make_water() -> void:
    var water := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(32, 20)
    mesh.subdivide_width = 2
    mesh.subdivide_depth = 2
    water.mesh = mesh
    water.position = Vector3(28.0, _ground_height(28.0, 18.0) - 0.25, 18.0)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.10, 0.25, 0.29, 0.72)
    material.metallic = 0.05
    material.roughness = 0.22
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water.material_override = material
    add_child(water)
