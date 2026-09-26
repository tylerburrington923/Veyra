extends StaticBody3D
class_name VeyraBuildingInstance

signal door_state_changed(building_id: String, open: bool)

var building_id: String = ""
var building_type: String = ""
var door_open := false
var _door_root: Node3D
var _door_collision: CollisionShape3D

const HOUSE_WIDTH := 5.8
const HOUSE_DEPTH := 4.8
const HOUSE_WALL_HEIGHT := 2.7
const HOUSE_DOOR_WIDTH := 1.2
const HOUSE_DOOR_HEIGHT := 2.15


func setup(id: String, type_id: String, position_value: Vector3, door_open_value: bool = false) -> void:
    building_id = id
    building_type = type_id
    door_open = door_open_value if type_id == "B03_SHELTER" else false
    global_position = position_value
    collision_layer = 2
    collision_mask = 1
    _build_visual()


func interact() -> void:
    if building_type != "B03_SHELTER" or not _door_root:
        return
    set_door_open(not door_open)


func can_interact(_player: Node) -> bool:
    return building_type == "B03_SHELTER" and _door_root != null


func get_interaction_point() -> Vector3:
    if building_type == "B03_SHELTER":
        return global_position + Vector3(0.0, 1.0, -HOUSE_DEPTH * 0.5 - 0.35)
    return global_position + Vector3.UP * 0.7


func get_interaction_text() -> String:
    if building_type == "B03_SHELTER":
        return "Close House Door" if door_open else "Open House Door"
    return ""


func set_door_open(open: bool) -> void:
    if building_type != "B03_SHELTER" or not _door_root:
        return
    if door_open == open:
        return
    door_open = open
    _door_root.rotation_degrees.y = 92.0 if door_open else 0.0
    if _door_collision:
        _door_collision.disabled = door_open
    door_state_changed.emit(building_id, door_open)


func _build_visual() -> void:
    for child in get_children():
        child.queue_free()
    _door_root = null
    _door_collision = null

    match building_type:
        "B01_CAMPFIRE":
            _build_campfire()
        "B02_STORAGE":
            _build_crate()
        "B03_SHELTER":
            _build_house()
        "B04_WELL":
            _build_well()
        _:
            _build_generic()


func _mesh_box(size: Vector3, position_value: Vector3, material: Material, rotation_value := Vector3.ZERO) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value
    mesh_instance.rotation = rotation_value
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance


func _mesh_cylinder(radius: float, height: float, position_value: Vector3, material: Material, segments: int = 8, rotation_value := Vector3.ZERO) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value
    mesh_instance.rotation = rotation_value
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance


func _mesh_sphere(radius: float, position_value: Vector3, material: Material, scale_value := Vector3.ONE) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 8
    mesh.rings = 4
    mesh_instance.mesh = mesh
    mesh_instance.position = position_value
    mesh_instance.scale = scale_value
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance


func _add_box_collision(size: Vector3, position_value: Vector3) -> CollisionShape3D:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    collision.position = position_value
    add_child(collision)
    return collision


func _material(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
    var material := _material(color, 0.55)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    return material


func _build_campfire() -> void:
    var stone := _material(Color(0.28, 0.31, 0.33))
    var stone_dark := _material(Color(0.19, 0.22, 0.24))
    var log_material := _material(Color(0.28, 0.13, 0.055))
    var ember := _emissive_material(Color(0.92, 0.18, 0.035), 2.2)
    var flame := _emissive_material(Color(1.0, 0.48, 0.08), 3.0)

    for i in range(10):
        var angle := TAU * float(i) / 10.0
        var radius := 0.72 if i % 2 == 0 else 0.66
        _mesh_cylinder(0.22, 0.25, Vector3(cos(angle) * radius, 0.125, sin(angle) * radius), stone if i % 3 else stone_dark, 7)

    for i in range(3):
        var angle := float(i) * PI / 3.0
        _mesh_box(Vector3(1.45, 0.16, 0.18), Vector3(0, 0.28 + i * 0.035, 0), log_material, Vector3(0, angle, deg_to_rad(5.0)))

    _mesh_sphere(0.31, Vector3(0, 0.38, 0), ember, Vector3(1.0, 0.55, 1.0))
    for i in range(3):
        var angle := TAU * float(i) / 3.0
        _mesh_sphere(0.18, Vector3(cos(angle) * 0.14, 0.58 + i * 0.08, sin(angle) * 0.14), flame, Vector3(0.75, 1.35, 0.75))


func _build_crate() -> void:
    var wood := _material(Color(0.34, 0.19, 0.075))
    var wood_light := _material(Color(0.48, 0.29, 0.12))
    var band := _material(Color(0.16, 0.18, 0.18), 0.48, 0.65)
    var dark := _material(Color(0.10, 0.075, 0.045))

    _mesh_box(Vector3(1.8, 1.2, 1.6), Vector3(0, 0.72, 0), wood)
    _mesh_box(Vector3(1.92, 0.13, 1.72), Vector3(0, 1.38, 0), wood_light)
    _mesh_box(Vector3(1.94, 0.08, 0.10), Vector3(0, 0.72, -0.82), band)
    _mesh_box(Vector3(1.94, 0.08, 0.10), Vector3(0, 0.72, 0.82), band)
    _mesh_box(Vector3(0.10, 1.30, 0.10), Vector3(-0.88, 0.72, 0), band)
    _mesh_box(Vector3(0.10, 1.30, 0.10), Vector3(0.88, 0.72, 0), band)
    _mesh_box(Vector3(0.14, 0.78, 0.08), Vector3(0, 0.82, -0.86), dark)
    for x in [-0.62, 0.0, 0.62]:
        _mesh_box(Vector3(0.11, 1.0, 1.66), Vector3(x, 0.72, 0), wood_light)

    for x in [-0.72, 0.72]:
        for z in [-0.62, 0.62]:
            _mesh_box(Vector3(0.20, 0.18, 0.20), Vector3(x, 0.09, z), dark)
    _add_box_collision(Vector3(1.8, 1.2, 1.6), Vector3(0, 0.72, 0))


func _build_house() -> void:
    var wall := _material(Color(0.31, 0.20, 0.11))
    var wall_light := _material(Color(0.43, 0.28, 0.14))
    var roof := _material(Color(0.12, 0.14, 0.16), 0.78)
    var trim := _material(Color(0.20, 0.12, 0.07))
    var window := _emissive_material(Color(0.24, 0.48, 0.50), 0.55)
    var door_material := _material(Color(0.24, 0.13, 0.07))
    var metal := _material(Color(0.18, 0.20, 0.21), 0.4, 0.65)

    # Floor and four-sided shell with a real front doorway.
    _mesh_box(Vector3(HOUSE_WIDTH, 0.16, HOUSE_DEPTH), Vector3(0, 0.08, 0), trim)
    _mesh_box(Vector3(HOUSE_WIDTH, HOUSE_WALL_HEIGHT, 0.20), Vector3(0, HOUSE_WALL_HEIGHT * 0.5, HOUSE_DEPTH * 0.5), wall)
    _mesh_box(Vector3(0.20, HOUSE_WALL_HEIGHT, HOUSE_DEPTH), Vector3(-HOUSE_WIDTH * 0.5, HOUSE_WALL_HEIGHT * 0.5, 0), wall)
    _mesh_box(Vector3(0.20, HOUSE_WALL_HEIGHT, HOUSE_DEPTH), Vector3(HOUSE_WIDTH * 0.5, HOUSE_WALL_HEIGHT * 0.5, 0), wall)
    var front_z := -HOUSE_DEPTH * 0.5
    var side_width := (HOUSE_WIDTH - HOUSE_DOOR_WIDTH) * 0.5
    _mesh_box(Vector3(side_width, HOUSE_WALL_HEIGHT, 0.20), Vector3(-(HOUSE_DOOR_WIDTH + side_width) * 0.5, HOUSE_WALL_HEIGHT * 0.5, front_z), wall)
    _mesh_box(Vector3(side_width, HOUSE_WALL_HEIGHT, 0.20), Vector3((HOUSE_DOOR_WIDTH + side_width) * 0.5, HOUSE_WALL_HEIGHT * 0.5, front_z), wall)
    _mesh_box(Vector3(HOUSE_DOOR_WIDTH + 0.35, 0.20, 0.22), Vector3(0, HOUSE_WALL_HEIGHT - 0.10, front_z), wall_light)

    # Gable roof: each panel spans the house depth and slopes across X.
    # The ridge is centered on X=0; the outer edges overhang the side walls.
    var roof_angle := deg_to_rad(25.0)
    var roof_half_span := (HOUSE_WIDTH + 0.45) * 0.5
    var roof_center_x := roof_half_span * cos(roof_angle)
    var roof_center_y := HOUSE_WALL_HEIGHT + roof_half_span * sin(roof_angle) + 0.08
    var roof_depth := HOUSE_DEPTH + 0.45
    var left_roof := _mesh_box(
        Vector3(HOUSE_WIDTH * 0.5 + 0.25, 0.20, roof_depth),
        Vector3(-roof_center_x, roof_center_y, 0),
        roof,
        Vector3(0, 0, roof_angle)
    )
    left_roof.name = "RoofLeft"
    var right_roof := _mesh_box(
        Vector3(HOUSE_WIDTH * 0.5 + 0.25, 0.20, roof_depth),
        Vector3(roof_center_x, roof_center_y, 0),
        roof,
        Vector3(0, 0, -roof_angle)
    )
    right_roof.name = "RoofRight"

    # Simple windows and exterior trim.
    _add_window(Vector3(-HOUSE_WIDTH * 0.5 - 0.015, 1.55, 0.0), Vector3(0, deg_to_rad(90), 0), window, trim)
    _add_window(Vector3(HOUSE_WIDTH * 0.5 + 0.015, 1.55, 0.0), Vector3(0, deg_to_rad(90), 0), window, trim)
    _mesh_box(Vector3(0.12, HOUSE_WALL_HEIGHT + 0.1, 0.12), Vector3(-HOUSE_WIDTH * 0.5, HOUSE_WALL_HEIGHT * 0.5, front_z - 0.08), trim)
    _mesh_box(Vector3(0.12, HOUSE_WALL_HEIGHT + 0.1, 0.12), Vector3(HOUSE_WIDTH * 0.5, HOUSE_WALL_HEIGHT * 0.5, front_z - 0.08), trim)

    # Hinged door: the building is the interaction authority, while this node
    # owns the door visual/collision state.
    _door_root = Node3D.new()
    _door_root.name = "Door"
    _door_root.position = Vector3(-HOUSE_DOOR_WIDTH * 0.5, HOUSE_DOOR_HEIGHT * 0.5, front_z - 0.13)
    add_child(_door_root)
    var door := MeshInstance3D.new()
    var door_mesh := BoxMesh.new()
    door_mesh.size = Vector3(HOUSE_DOOR_WIDTH, HOUSE_DOOR_HEIGHT, 0.14)
    door.mesh = door_mesh
    door.position = Vector3(HOUSE_DOOR_WIDTH * 0.5, 0, 0)
    door.material_override = door_material
    _door_root.add_child(door)

    var handle := MeshInstance3D.new()
    var handle_mesh := SphereMesh.new()
    handle_mesh.radius = 0.06
    handle_mesh.height = 0.12
    handle.mesh = handle_mesh
    handle.position = Vector3(HOUSE_DOOR_WIDTH - 0.18, 0.0, -0.10)
    handle.material_override = metal
    _door_root.add_child(handle)

    _door_collision = CollisionShape3D.new()
    var door_shape := BoxShape3D.new()
    door_shape.size = Vector3(HOUSE_DOOR_WIDTH, HOUSE_DOOR_HEIGHT, 0.16)
    _door_collision.shape = door_shape
    _door_collision.position = Vector3(HOUSE_DOOR_WIDTH * 0.5, 0, 0)
    _door_root.add_child(_door_collision)

    _add_box_collision(Vector3(HOUSE_WIDTH, 0.16, HOUSE_DEPTH), Vector3(0, 0.08, 0))
    var back_wall_collision := _add_box_collision(
        Vector3(HOUSE_WIDTH, HOUSE_WALL_HEIGHT, 0.20),
        Vector3(0, HOUSE_WALL_HEIGHT * 0.5, HOUSE_DEPTH * 0.5)
    )
    back_wall_collision.name = "BackWallCollision"
    _add_box_collision(Vector3(0.20, HOUSE_WALL_HEIGHT, HOUSE_DEPTH), Vector3(-HOUSE_WIDTH * 0.5, HOUSE_WALL_HEIGHT * 0.5, 0))
    _add_box_collision(Vector3(0.20, HOUSE_WALL_HEIGHT, HOUSE_DEPTH), Vector3(HOUSE_WIDTH * 0.5, HOUSE_WALL_HEIGHT * 0.5, 0))
    _add_box_collision(Vector3(side_width, HOUSE_WALL_HEIGHT, 0.20), Vector3(-(HOUSE_DOOR_WIDTH + side_width) * 0.5, HOUSE_WALL_HEIGHT * 0.5, front_z))
    _add_box_collision(Vector3(side_width, HOUSE_WALL_HEIGHT, 0.20), Vector3((HOUSE_DOOR_WIDTH + side_width) * 0.5, HOUSE_WALL_HEIGHT * 0.5, front_z))
    _door_collision.disabled = door_open
    _door_root.rotation_degrees.y = 92.0 if door_open else 0.0


func _add_window(position_value: Vector3, rotation_value: Vector3, glass: Material, frame: Material) -> void:
    var basis := Basis.from_euler(rotation_value)
    _mesh_box(Vector3(0.95, 0.85, 0.08), position_value, glass, rotation_value)
    _mesh_box(Vector3(1.08, 0.10, 0.10), position_value + basis * Vector3(0, 0.48, 0), frame, rotation_value)
    _mesh_box(Vector3(1.08, 0.10, 0.10), position_value + basis * Vector3(0, -0.48, 0), frame, rotation_value)
    _mesh_box(Vector3(0.10, 1.08, 0.10), position_value + basis * Vector3(0.48, 0, 0), frame, rotation_value)
    _mesh_box(Vector3(0.10, 1.08, 0.10), position_value + basis * Vector3(-0.48, 0, 0), frame, rotation_value)


func _build_well() -> void:
    var stone := _material(Color(0.31, 0.33, 0.35))
    var stone_light := _material(Color(0.43, 0.45, 0.45))
    var dark := _material(Color(0.07, 0.08, 0.09))
    var wood := _material(Color(0.29, 0.16, 0.07))
    var roof := _material(Color(0.14, 0.16, 0.17))
    var water := _emissive_material(Color(0.08, 0.35, 0.42), 0.45)

    for i in range(12):
        var angle := TAU * float(i) / 12.0
        var radius := 0.93
        _mesh_cylinder(0.30, 0.45, Vector3(cos(angle) * radius, 0.23, sin(angle) * radius), stone if i % 2 else stone_light, 7)
    _mesh_cylinder(0.76, 0.05, Vector3(0, 0.49, 0), water, 12)

    for x in [-0.95, 0.95]:
        _mesh_box(Vector3(0.18, 2.1, 0.18), Vector3(x, 1.05, 0), wood)
    _mesh_box(Vector3(2.25, 0.16, 0.18), Vector3(0, 2.0, 0), wood)
    _mesh_cylinder(0.08, 2.0, Vector3(0, 1.25, 0), dark, 8, Vector3(0, 0, deg_to_rad(90)))
    _mesh_box(Vector3(2.4, 0.18, 1.25), Vector3(0, 2.25, 0), roof, Vector3(deg_to_rad(2.0), 0, 0))
    _mesh_box(Vector3(2.2, 0.18, 1.15), Vector3(0, 2.35, 0), roof, Vector3(deg_to_rad(-2.0), 0, 0))
    _add_box_collision(Vector3(2.2, 0.55, 2.2), Vector3(0, 0.28, 0))


func _build_generic() -> void:
    var material := _material(Color(0.35, 0.28, 0.18))
    _mesh_box(Vector3(2.0, 1.5, 2.0), Vector3(0, 0.75, 0), material)
    _add_box_collision(Vector3(2.0, 1.5, 2.0), Vector3(0, 0.75, 0))
