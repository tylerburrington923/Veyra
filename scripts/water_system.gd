extends Node3D

## Deterministic presentation-only water. Terrain remains authoritative.
@export var seed_value: int = 47291
@export var lake_radius: float = 11.0
@export var lake_segments: int = 24
@export var stream_points: int = 22
@export var stream_width: float = 2.4

var generated := false
var terrain_generator: Node
var lake_center := Vector3.ZERO
var lake_level := 0.0
var water_material: StandardMaterial3D
var shore_material: StandardMaterial3D

func _ready() -> void:
    call_deferred("generate")

func configure(world_seed: int) -> void:
    seed_value = world_seed

func generate() -> void:
    if generated:
        return
    if terrain_generator == null:
        var parent_node: Node = get_parent()
        if parent_node and parent_node.has_method("get_height_at_world"):
            terrain_generator = parent_node
        elif parent_node:
            terrain_generator = parent_node.get_node_or_null("WorldGenerator")
        if terrain_generator == null:
            for candidate in get_tree().get_nodes_in_group("world_generator"):
                if candidate and candidate.has_method("get_height_at_world"):
                    terrain_generator = candidate
                    break
    if terrain_generator == null or not terrain_generator.has_method("get_height_at_world"):
        return
    generated = true
    lake_center = _find_low_point(Vector2(-32.0 + float(posmod(seed_value, 11)), 12.0 + float(posmod(seed_value / 11, 9))))
    lake_level = float(terrain_generator.get_height_at_world(lake_center.x, lake_center.z)) + 0.32
    _make_lake()
    _make_stream()

func is_generated() -> bool:
    return generated

func get_lake_center() -> Vector3:
    return lake_center

func get_lake_level() -> float:
    return lake_level

func _find_low_point(origin: Vector2) -> Vector3:
    var best := Vector3(origin.x, 0.0, origin.y)
    var best_height := INF
    for z in range(11):
        for x in range(11):
            var offset := Vector2(float(x - 5) * 1.6, float(z - 5) * 1.6)
            if offset.length() > 8.0:
                continue
            var px := origin.x + offset.x
            var pz := origin.y + offset.y
            var h: float = terrain_generator.get_height_at_world(px, pz)
            if h < best_height:
                best_height = h
                best = Vector3(px, h, pz)
    return best

func _make_lake() -> void:
    var v := PackedVector3Array([Vector3(lake_center.x, lake_level, lake_center.z)])
    var n := PackedVector3Array([Vector3.UP])
    var u := PackedVector2Array([Vector2(0.5, 0.5)])
    var idx := PackedInt32Array()
    for i in range(lake_segments):
        var a := TAU * float(i) / lake_segments
        var r := lake_radius * (0.86 + 0.08 * sin(float(i) * 2.7 + float(seed_value % 17)))
        var p := Vector3(lake_center.x + cos(a) * r, lake_level, lake_center.z + sin(a) * r)
        var h: float = terrain_generator.get_height_at_world(p.x, p.z)
        p.y = minf(lake_level, h + 0.08)
        v.append(p)
        n.append(Vector3.UP)
        u.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
    for i in range(lake_segments):
        idx.append_array(PackedInt32Array([0, i + 1, (i + 1) % lake_segments + 1]))
    _surface("LakeSurface", v, n, u, idx, _water())
    _shore()

func _shore() -> void:
    var v := PackedVector3Array()
    var n := PackedVector3Array()
    var u := PackedVector2Array()
    var idx := PackedInt32Array()
    for i in range(lake_segments):
        var a := TAU * float(i) / lake_segments
        for r in [lake_radius * 1.04, lake_radius * 0.91]:
            var p := Vector3(lake_center.x + cos(a) * r, 0.0, lake_center.z + sin(a) * r)
            p.y = lake_level - 0.015 if r < lake_radius else float(terrain_generator.get_height_at_world(p.x, p.z)) + 0.015
            v.append(p)
            n.append(Vector3.UP)
            u.append(Vector2(float(i) / lake_segments, 0.0 if r > lake_radius else 1.0))
    for i in range(lake_segments):
        var j := (i + 1) % lake_segments
        idx.append_array(PackedInt32Array([i * 2, j * 2, i * 2 + 1, i * 2 + 1, j * 2, j * 2 + 1]))
    _surface("LakeShore", v, n, u, idx, _shore_material())

func _make_stream() -> void:
    var dir := Vector2(0.82, 0.57).normalized()
    var side := Vector2(-dir.y, dir.x)
    var v := PackedVector3Array()
    var n := PackedVector3Array()
    var u := PackedVector2Array()
    var idx := PackedInt32Array()
    var start := Vector2(lake_center.x, lake_center.z) + dir * (lake_radius * 0.75)
    var previous := start
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + 1703
    for i in range(stream_points):
        var t := float(i) / float(stream_points - 1)
        var p := start + dir * (3.0 + 2.0 * t) * i + side * (sin(t * 8.0 + seed_value % 13) * 1.7 + rng.randf_range(-0.3, 0.3))
        if i > 0 and p.distance_to(previous) > 5.0:
            p = previous + (p - previous).normalized() * 5.0
        previous = p
        var h: float = terrain_generator.get_height_at_world(p.x, p.y) + 0.12
        var w := lerpf(stream_width * 0.72, stream_width * 1.15, t)
        v.append(Vector3(p.x + side.x * w, h, p.y + side.y * w))
        v.append(Vector3(p.x - side.x * w, h, p.y - side.y * w))
        n.append(Vector3.UP)
        n.append(Vector3.UP)
        u.append(Vector2(0.0, t))
        u.append(Vector2(1.0, t))
    for i in range(stream_points - 1):
        var a := i * 2
        idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
    _surface("StreamSurface", v, n, u, idx, _water())

func _surface(name_: String, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, material: StandardMaterial3D) -> void:
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh.surface_set_material(0, material)
    var node := MeshInstance3D.new()
    node.name = name_
    node.mesh = mesh
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _water() -> StandardMaterial3D:
    if water_material:
        return water_material
    water_material = StandardMaterial3D.new()
    water_material.albedo_color = Color(0.10, 0.34, 0.38, 0.78)
    water_material.roughness = 0.16
    water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return water_material

func _shore_material() -> StandardMaterial3D:
    if shore_material:
        return shore_material
    shore_material = StandardMaterial3D.new()
    shore_material.albedo_color = Color(0.30, 0.25, 0.15, 0.72)
    shore_material.roughness = 0.92
    shore_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shore_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return shore_material
