extends Node3D

## Lightweight deterministic terrain for the first Veyra vertical slice.
## The same seed rebuilds the same base landscape on every peer.

@export var seed_value := 47291
@export var grid_size := 48
@export var cell_size := 4.0
@export var height_scale := 7.0
@export var resource_count := 36

var noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()

func _ready() -> void:
    generate()

func generate() -> void:
    noise.seed = seed_value
    noise.frequency = 0.018
    noise.fractal_octaves = 3
    detail_noise.seed = seed_value + 41
    detail_noise.frequency = 0.055
    detail_noise.fractal_octaves = 2

    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    for z in range(grid_size + 1):
        for x in range(grid_size + 1):
            var px := (x - grid_size * 0.5) * cell_size
            var pz := (z - grid_size * 0.5) * cell_size
            var base_h := noise.get_noise_2d(x, z) * height_scale
            var detail_h := detail_noise.get_noise_2d(x, z) * 1.2
            var h := get_height_at_world(px, pz)
            vertices.append(Vector3(px, h, pz))
            normals.append(_sample_normal(x, z))
            uvs.append(Vector2(float(x) / grid_size, float(z) / grid_size))

    for z in range(grid_size):
        for x in range(grid_size):
            var row := grid_size + 1
            var a := z * row + x
            var b := a + 1
            var c := a + row
            var d := c + 1
            indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.22, 0.27, 0.21, 1)
    material.roughness = 1.0
    mesh.surface_set_material(0, material)

    var terrain := MeshInstance3D.new()
    terrain.name = "Terrain"
    terrain.mesh = mesh
    add_child(terrain)

    var body := StaticBody3D.new()
    body.name = "TerrainCollision"
    var collision := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(mesh.get_faces())
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

    _spawn_resources()
    _spawn_landmark()

func get_height_at_world(x: float, z: float) -> float:
    var sample_x := x / cell_size + grid_size * 0.5
    var sample_z := z / cell_size + grid_size * 0.5
    return noise.get_noise_2d(sample_x, sample_z) * height_scale + detail_noise.get_noise_2d(sample_x, sample_z) * 1.2

func _sample_normal(x: int, z: int) -> Vector3:
    var left := get_height_at_world((x - 1 - grid_size * 0.5) * cell_size, (z - grid_size * 0.5) * cell_size)
    var right := get_height_at_world((x + 1 - grid_size * 0.5) * cell_size, (z - grid_size * 0.5) * cell_size)
    var back := get_height_at_world((x - grid_size * 0.5) * cell_size, (z - 1 - grid_size * 0.5) * cell_size)
    var front := get_height_at_world((x - grid_size * 0.5) * cell_size, (z + 1 - grid_size * 0.5) * cell_size)
    return Vector3(left - right, 2.0, back - front).normalized()

func _spawn_resources() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + 991

    for i in range(resource_count):
        var x := rng.randf_range(-grid_size * cell_size * 0.45, grid_size * cell_size * 0.45)
        var z := rng.randf_range(-grid_size * cell_size * 0.45, grid_size * cell_size * 0.45)

        if Vector2(x, z).length() < 10.0:
            continue

        var y := get_height_at_world(x, z) + 0.7
        add_child(_make_resource_node(i, Vector3(x, y, z)))

func _make_resource_node(index: int, spawn_position: Vector3) -> StaticBody3D:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + index * 17
    var types := ["Stone", "Wood", "Metal", "Vitreous Lux"]
    var resource_type: String = types[rng.randi_range(0, types.size() - 1)]

    var node := StaticBody3D.new()
    node.name = resource_type + "_" + str(index)
    node.position = spawn_position
    node.set_script(load("res://scripts/resource_node.gd"))
    node.resource_type = resource_type
    node.amount = 1

    var mesh := SphereMesh.new()
    mesh.radius = 0.55
    mesh.height = 1.1

    var material := StandardMaterial3D.new()
    material.roughness = 0.85
    material.albedo_color = _resource_color(resource_type)
    if resource_type == "Vitreous Lux":
        material.emission_enabled = true
        material.emission = Color(0.02, 0.35, 0.4, 1)
        material.emission_energy_multiplier = 1.4

    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material
    node.add_child(visual)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.55
    collision.shape = shape
    node.add_child(collision)

    return node

func _spawn_landmark() -> void:
    var base := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.8
    mesh.height = 5.5
    mesh.radial_segments = 8
    base.mesh = mesh
    base.position = Vector3(0, get_height_at_world(0.0, -18.0) + 2.75, -18)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.28, 0.25, 0.22, 1)
    material.roughness = 0.92
    base.material_override = material
    add_child(base)

    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 1.25
    ring_mesh.outer_radius = 1.38
    ring_mesh.rings = 8
    ring_mesh.ring_segments = 12
    ring.mesh = ring_mesh
    ring.position = Vector3(0, get_height_at_world(0.0, -18.0) + 4.7, -18)

    var lux := StandardMaterial3D.new()
    lux.albedo_color = Color(0.08, 0.48, 0.52, 1)
    lux.emission_enabled = true
    lux.emission = Color(0.02, 0.32, 0.36, 1)
    lux.emission_energy_multiplier = 1.4
    ring.material_override = lux
    add_child(ring)

func _resource_color(resource_type: String) -> Color:
    match resource_type:
        "Stone":
            return Color(0.35, 0.38, 0.36, 1)
        "Wood":
            return Color(0.34, 0.22, 0.10, 1)
        "Metal":
            return Color(0.35, 0.40, 0.44, 1)
        "Echo-Stone":
            return Color(0.32, 0.18, 0.48, 1)
        "Vitreous Lux":
            return Color(0.10, 0.55, 0.60, 1)
    return Color.WHITE
