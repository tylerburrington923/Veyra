extends Node3D

## Lightweight deterministic terrain for the first Veyra vertical slice.
## The same seed rebuilds the same base landscape on every peer.

@export var seed_value := 47291
@export var grid_size := 48
@export var cell_size := 4.0
@export var height_scale := 7.0
@export var resource_count := 36

var noise := FastNoiseLite.new()

func _ready() -> void:
    generate()

func generate() -> void:
    noise.seed = seed_value
    noise.frequency = 0.018
    noise.fractal_octaves = 4

    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    for z in range(grid_size + 1):
        for x in range(grid_size + 1):
            var px := (x - grid_size * 0.5) * cell_size
            var pz := (z - grid_size * 0.5) * cell_size
            var h := noise.get_noise_2d(x, z) * height_scale
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
    material.albedo_color = Color(0.20, 0.24, 0.20, 1)
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

func _sample_normal(x: int, z: int) -> Vector3:
    var left := noise.get_noise_2d(x - 1, z) * height_scale
    var right := noise.get_noise_2d(x + 1, z) * height_scale
    var back := noise.get_noise_2d(x, z - 1) * height_scale
    var front := noise.get_noise_2d(x, z + 1) * height_scale
    return Vector3(left - right, 2.0, back - front).normalized()

func _spawn_resources() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + 991

    for i in range(resource_count):
        var x := rng.randf_range(-grid_size * cell_size * 0.45, grid_size * cell_size * 0.45)
        var z := rng.randf_range(-grid_size * cell_size * 0.45, grid_size * cell_size * 0.45)

        if Vector2(x, z).length() < 10.0:
            continue

        var sample_x := x / cell_size + grid_size * 0.5
        var sample_z := z / cell_size + grid_size * 0.5
        var y := noise.get_noise_2d(sample_x, sample_z) * height_scale + 0.7
        add_child(_make_resource_node(i, Vector3(x, y, z)))

func _make_resource_node(index: int, spawn_position: Vector3) -> StaticBody3D:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + index * 17
    var types := ["Stone", "Wood", "Metal", "Echo-Stone", "Vitreous Lux"]
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
