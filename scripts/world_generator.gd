extends Node3D

## Deterministic terrain and resource generation for Veyra.
## Visuals stay procedural so the mobile build does not depend on large texture assets.

@export var seed_value := 47291
@export var grid_size := 48
@export var cell_size := 4.0
@export var height_scale := 7.0
@export var resource_count := 36

var noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var generated := false
var terrain_collision: StaticBody3D
var resource_textures: Dictionary = {}
var resource_meshes: Dictionary = {}
var resource_materials: Dictionary = {}
var resource_collision_shape := SphereShape3D.new()
var saved_resource_state: Dictionary = {}

func _ready() -> void:
    resource_collision_shape.radius = 0.58
    call_deferred("generate")

func generate() -> void:
    if generated:
        return

    generated = true
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
    material.albedo_texture = _make_terrain_texture()
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_BACK
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mesh.surface_set_material(0, material)

    var terrain := MeshInstance3D.new()
    terrain.name = "Terrain"
    terrain.mesh = mesh
    add_child(terrain)

    var body := StaticBody3D.new()
    body.name = "TerrainCollision"
    body.collision_layer = 1
    body.collision_mask = 1
    var collision := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(mesh.get_faces())
    shape.backface_collision = true
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    terrain_collision = body

    _spawn_resources()
    _spawn_landmark()

func is_generated() -> bool:
    return generated and is_instance_valid(terrain_collision)

func set_saved_resource_state(state: Dictionary) -> void:
    saved_resource_state = state.duplicate(true)

func get_resource_state() -> Dictionary:
    var state := {}
    for child in get_children():
        if child is VeyraResourceNode:
            var resource := child as VeyraResourceNode
            var saved := resource.get_save_state()
            if not saved.is_empty():
                state[resource.resource_id] = saved
    return state


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

    var spawned := 0
    var attempts := 0
    var max_attempts := maxi(resource_count * 3, 12)

    while spawned < resource_count and attempts < max_attempts:
        attempts += 1
        var x := rng.randf_range(-grid_size * cell_size * 0.45, grid_size * cell_size * 0.45)
        var z := rng.randf_range(-grid_size * cell_size * 0.45, grid_size * cell_size * 0.45)

        if Vector2(x, z).length() < 10.0:
            continue

        var y: float = get_height_at_world(x, z) + 0.82
        add_child(_make_resource_node(spawned, Vector3(x, y, z)))
        spawned += 1

func _make_resource_node(index: int, spawn_position: Vector3) -> VeyraResourceNode:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + index * 17
    var types := ["Stone", "Wood", "Metal", "Vitreous Lux"]
    var resource_type: String = types[rng.randi_range(0, types.size() - 1)]

    var node := VeyraResourceNode.new()
    node.resource_id = "R01-%03d" % (index + 1)
    node.name = node.resource_id
    node.position = spawn_position
    node.resource_type = resource_type
    node.amount = 3
    node.collision_layer = 2
    node.collision_mask = 1

    var visual := MeshInstance3D.new()
    visual.mesh = _resource_mesh(resource_type)
    visual.material_override = _resource_material(resource_type)
    visual.rotation.y = rng.randf_range(0.0, TAU)
    visual.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
    node.add_child(visual)

    var collision := CollisionShape3D.new()
    collision.shape = resource_collision_shape
    node.add_child(collision)

    if saved_resource_state.has(node.resource_id):
        node.apply_save_state(saved_resource_state[node.resource_id])

    return node

func _resource_mesh(resource_type: String) -> Mesh:
    if resource_meshes.has(resource_type):
        return resource_meshes[resource_type]
    var mesh: Mesh
    match resource_type:
        "Stone":
            var stone := SphereMesh.new()
            stone.radius = 0.62
            stone.height = 0.9
            stone.radial_segments = 8
            stone.rings = 4
            mesh = stone
        "Wood":
            var wood := CylinderMesh.new()
            wood.top_radius = 0.45
            wood.bottom_radius = 0.58
            wood.height = 0.85
            wood.radial_segments = 8
            mesh = wood
        "Metal":
            var metal := PrismMesh.new()
            metal.size = Vector3(0.95, 1.0, 0.95)
            mesh = metal
        _:
            var lux := PrismMesh.new()
            lux.size = Vector3(0.72, 1.45, 0.72)
            mesh = lux
    resource_meshes[resource_type] = mesh
    return mesh

func _resource_material(resource_type: String) -> StandardMaterial3D:
    if resource_materials.has(resource_type):
        return resource_materials[resource_type]
    var material := StandardMaterial3D.new()
    material.albedo_texture = _make_resource_texture(resource_type)
    material.roughness = 0.82
    match resource_type:
        "Stone":
            material.albedo_color = Color(0.72, 0.75, 0.70, 1)
        "Wood":
            material.albedo_color = Color(0.70, 0.42, 0.20, 1)
        "Metal":
            material.albedo_color = Color(0.62, 0.68, 0.72, 1)
            material.metallic = 0.72
            material.roughness = 0.38
        "Vitreous Lux":
            material.albedo_color = Color(0.20, 0.80, 0.84, 1)
            material.emission_enabled = true
            material.emission = Color(0.02, 0.34, 0.38, 1)
            material.emission_energy_multiplier = 1.25
    resource_materials[resource_type] = material
    return material

func _make_terrain_texture() -> ImageTexture:
    var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var texture_noise := FastNoiseLite.new()
    texture_noise.seed = seed_value + 8000
    texture_noise.frequency = 0.028
    texture_noise.fractal_octaves = 2

    var grass := Color(0.25, 0.40, 0.20, 1)
    var grass_light := Color(0.31, 0.47, 0.24, 1)
    var soil := Color(0.30, 0.25, 0.16, 1)

    for y in range(128):
        for x in range(128):
            var n := texture_noise.get_noise_2d(float(x), float(y))
            var fine := texture_noise.get_noise_2d(float(x) * 3.0, float(y) * 3.0) * 0.06
            var v := clampf(0.5 + n * 0.30 + fine, 0.0, 1.0)
            var color := grass.lerp(grass_light, clampf((v - 0.25) * 1.35, 0.0, 1.0))
            color = color.lerp(soil, clampf((0.34 - v) * 2.0, 0.0, 0.65))
            image.set_pixel(x, y, color)

    return ImageTexture.create_from_image(image)

func _make_resource_texture(resource_type: String) -> ImageTexture:
    if resource_textures.has(resource_type):
        return resource_textures[resource_type]

    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var texture_noise := FastNoiseLite.new()
    texture_noise.seed = seed_value + resource_type.hash()
    texture_noise.frequency = 0.12

    var base := Color.WHITE
    var dark := Color(0.45, 0.45, 0.45, 1)
    match resource_type:
        "Stone":
            base = Color(0.66, 0.68, 0.64, 1)
            dark = Color(0.30, 0.32, 0.30, 1)
        "Wood":
            base = Color(0.62, 0.35, 0.14, 1)
            dark = Color(0.26, 0.12, 0.045, 1)
        "Metal":
            base = Color(0.64, 0.69, 0.74, 1)
            dark = Color(0.20, 0.24, 0.28, 1)
        "Vitreous Lux":
            base = Color(0.14, 0.72, 0.76, 1)
            dark = Color(0.025, 0.16, 0.20, 1)

    for y in range(32):
        for x in range(32):
            var n := clampf(0.5 + texture_noise.get_noise_2d(float(x), float(y)) * 0.5, 0.0, 1.0)
            image.set_pixel(x, y, dark.lerp(base, n))

    var texture := ImageTexture.create_from_image(image)
    resource_textures[resource_type] = texture
    return texture

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

