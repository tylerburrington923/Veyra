extends StaticBody3D
class_name VeyraBuildingInstance

const BUILDING_UI_SCRIPT = preload("res://scripts/building_ui.gd")

signal door_state_changed(building_id: String, open: bool)

var building_id: String = ""
var building_type: String = ""
var door_open := false
var _door_root: Node3D
var _door_collision: CollisionShape3D
var _last_interaction_feedback := ""
var campfire_heat_seconds: float = 0.0
var _campfire_save_accumulator: float = 0.0

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
    add_to_group("interactable")
    _build_visual()
    _last_interaction_feedback = ""
    _load_campfire_state()
    set_process(type_id == "B01_CAMPFIRE")


func interact(player_override: Node = null) -> void:
    _last_interaction_feedback = ""
    var player: Node = player_override if player_override else get_tree().get_first_node_in_group("local_player")
    match building_type:
        "B01_CAMPFIRE":
            _open_building_ui(player, "campfire")
        "B02_STORAGE":
            _toggle_storage(player)
        "B03_SHELTER":
            if _door_root:
                set_door_open(not door_open)
                _last_interaction_feedback = "House door opened." if door_open else "House door closed."
        "B04_WELL":
            var settlement := get_node_or_null("/root/SettlementManager")
            if settlement and settlement.has_method("add_stock"):
                settlement.add_stock("Water", 5)
                _last_interaction_feedback = "Well: +5 Water to settlement reserve."
            else:
                _last_interaction_feedback = "Well: settlement reserve unavailable."
        "B05_TOWNHALL":
            _open_building_ui(player, "townhall")
            var town_settlement := get_node_or_null("/root/SettlementManager")
            if town_settlement:
                var population := int(town_settlement.get("population"))
                _last_interaction_feedback = "Town Hall: population %d." % population
            else:
                _last_interaction_feedback = "Town Hall: settlement system unavailable."
        "B06_SHRINE":
            _last_interaction_feedback = "The shrine hums softly. The Lux remembers you."
        "B07_WATCHTOWER":
            _last_interaction_feedback = "The high ground reveals the lunar horizon."
        "B08_GARDEN":
            var garden_settlement := get_node_or_null("/root/SettlementManager")
            if garden_settlement and garden_settlement.has_method("add_stock"):
                garden_settlement.add_stock("Food", 1)
                _last_interaction_feedback = "Lunar Garden: +1 Food."
            else:
                _last_interaction_feedback = "Lunar Garden: settlement reserve unavailable."
        _:
            _last_interaction_feedback = "Nothing to use here."


func can_interact(player: Node) -> bool:
    match building_type:
        "B03_SHELTER":
            return _door_root != null
        "B02_STORAGE":
            return player != null
        "B01_CAMPFIRE", "B04_WELL", "B05_TOWNHALL", "B06_SHRINE", "B07_WATCHTOWER", "B08_GARDEN":
            return true
        _:
            return false


func get_interaction_point() -> Vector3:
    match building_type:
        "B03_SHELTER":
            return global_position + Vector3(0.0, 1.0, -HOUSE_DEPTH * 0.5 - 0.35)
        "B01_CAMPFIRE":
            return global_position + Vector3(0.0, 0.55, -0.85)
        "B02_STORAGE":
            return global_position + Vector3(0.0, 0.85, -0.85)
        "B04_WELL":
            return global_position + Vector3(0.0, 0.65, -0.8)
        "B05_TOWNHALL":
            return global_position + Vector3(0.0, 1.0, -3.7)
        "B06_SHRINE":
            return global_position + Vector3(0.0, 1.0, -1.0)
        "B07_WATCHTOWER":
            return global_position + Vector3(0.0, 2.0, -1.0)
        "B08_GARDEN":
            return global_position + Vector3(0.4, 0.5, -1.0)
        _:
            return global_position + Vector3.UP * 0.7


func get_interaction_text() -> String:
    match building_type:
        "B01_CAMPFIRE":
            return "Open Campfire"
        "B02_STORAGE":
            return "Open Storage"
        "B03_SHELTER":
            return "Close House Door" if door_open else "Open House Door"
        "B04_WELL":
            return "Use Well"
        "B05_TOWNHALL":
            return "Open Town Hall"
        "B06_SHRINE":
            return "Attune Resonance Shrine"
        "B07_WATCHTOWER":
            return "Survey from Watchtower"
        "B08_GARDEN":
            return "Tend Lunar Garden"
        _:
            return "Use"


func get_interaction_feedback() -> String:
    return _last_interaction_feedback


func _toggle_storage(player: Node) -> void:
    if not player:
        _last_interaction_feedback = "Storage: player unavailable."
        return
    var inventory: VeyraInventory = player.get_node_or_null("Inventory") as VeyraInventory
    var settlement := get_node_or_null("/root/SettlementManager")
    if not inventory or not settlement:
        _last_interaction_feedback = "Storage: inventory unavailable."
        return
    var storage: Dictionary = settlement.get_building_storage(building_id) if settlement.has_method("get_building_storage") else {}
    if storage.is_empty():
        storage = {"resources": {}, "items": {}}
    if not (storage.get("resources", {}) is Dictionary):
        storage["resources"] = {}
    if not (storage.get("items", {}) is Dictionary):
        storage["items"] = {}

    var carried_resources: Dictionary = inventory.get_snapshot().get("resources", {})
    var carried_items: Dictionary = inventory.get_snapshot().get("items", {})
    var stored_any := false

    for resource_type in carried_resources.keys():
        var amount := int(carried_resources[resource_type])
        if amount <= 0:
            continue
        var removed := inventory.remove_resource(str(resource_type), amount)
        if removed > 0:
            storage["resources"][str(resource_type)] = int(storage["resources"].get(str(resource_type), 0)) + removed
            stored_any = true

    for item_id in carried_items.keys():
        var amount := int(carried_items[item_id])
        if amount <= 0:
            continue
        var removed := inventory.remove_item(str(item_id), amount)
        if removed > 0:
            storage["items"][str(item_id)] = int(storage["items"].get(str(item_id), 0)) + removed
            stored_any = true

    if stored_any:
        settlement.set_building_storage(building_id, storage)
        _last_interaction_feedback = "Storage: all carried goods deposited."
        return

    var withdrawn := 0
    var stored_resources: Dictionary = storage.get("resources", {})
    for resource_type in stored_resources.keys():
        var amount := int(stored_resources[resource_type])
        if amount <= 0:
            continue
        var accepted := inventory.add_resource(str(resource_type), amount)
        if accepted > 0:
            stored_resources[resource_type] = amount - accepted
            withdrawn += accepted
            if stored_resources[resource_type] <= 0:
                stored_resources.erase(resource_type)

    var stored_items: Dictionary = storage.get("items", {})
    for item_id in stored_items.keys():
        var amount := int(stored_items[item_id])
        if amount <= 0:
            continue
        var accepted := inventory.add_item(str(item_id), amount)
        if accepted > 0:
            stored_items[item_id] = amount - accepted
            withdrawn += accepted
            if stored_items[item_id] <= 0:
                stored_items.erase(item_id)

    storage["resources"] = stored_resources
    storage["items"] = stored_items
    settlement.set_building_storage(building_id, storage)
    _last_interaction_feedback = "Storage: withdrew %d items." % withdrawn if withdrawn > 0 else "Storage is empty."



func deposit_civic_materials(player: Node, amount_per_resource: int = 10) -> bool:
    if building_type != "B05_TOWNHALL" or not player or amount_per_resource <= 0:
        return false
    var inventory: VeyraInventory = player.get_node_or_null("Inventory") as VeyraInventory
    var settlement := get_node_or_null("/root/SettlementManager")
    if not inventory or not settlement or not settlement.has_method("add_stock"):
        return false
    var deposited := 0
    var wood := inventory.remove_resource("Wood", amount_per_resource)
    var stone := inventory.remove_resource("Stone", amount_per_resource)
    if wood > 0:
        settlement.add_stock("Wood", wood)
        deposited += wood
    if stone > 0:
        settlement.add_stock("Stone", stone)
        deposited += stone
    _last_interaction_feedback = "Town Hall: deposited %d civic materials." % deposited if deposited > 0 else "Town Hall: nothing to deposit."
    return deposited > 0

func _open_building_ui(player: Node, mode: String) -> void:
    if not player:
        return
    var ui := player.get_node_or_null("BuildingUI")
    if not ui:
        ui = BUILDING_UI_SCRIPT.new()
        ui.name = "BuildingUI"
        player.add_child(ui)
    if mode == "campfire" and ui.has_method("open_campfire"):
        ui.open_campfire(self, player)
    elif mode == "townhall" and ui.has_method("open_townhall"):
        ui.open_townhall(self, player)

func add_campfire_fuel(player: Node, amount: int = 1) -> bool:
    if building_type != "B01_CAMPFIRE" or not player or amount <= 0:
        return false
    var inventory: VeyraInventory = player.get_node_or_null("Inventory") as VeyraInventory
    if not inventory:
        return false
    var removed := inventory.remove_resource("Wood", amount)
    if removed <= 0:
        return false
    campfire_heat_seconds += float(removed) * 30.0
    _campfire_save_accumulator = 0.0
    set_process(true)
    _persist_campfire_state()
    _last_interaction_feedback = "Campfire: +%d wood fuel." % removed
    return true

func get_campfire_heat() -> float:
    return maxf(0.0, campfire_heat_seconds)

func _load_campfire_state() -> void:
    campfire_heat_seconds = 0.0
    if building_type != "B01_CAMPFIRE":
        return
    var settlement := get_node_or_null("/root/SettlementManager")
    if not settlement or not settlement.has_method("get_building_storage"):
        return
    var storage: Dictionary = settlement.get_building_storage(building_id)
    campfire_heat_seconds = maxf(0.0, float(storage.get("campfire_heat", 0.0)))

func _persist_campfire_state() -> void:
    if building_type != "B01_CAMPFIRE":
        return
    var settlement := get_node_or_null("/root/SettlementManager")
    if not settlement or not settlement.has_method("get_building_storage"):
        return
    var storage: Dictionary = settlement.get_building_storage(building_id)
    storage["campfire_heat"] = maxf(0.0, campfire_heat_seconds)
    settlement.set_building_storage(building_id, storage)

func _process(delta: float) -> void:
    if building_type != "B01_CAMPFIRE" or campfire_heat_seconds <= 0.0:
        if building_type == "B01_CAMPFIRE":
            set_process(false)
        return
    campfire_heat_seconds = maxf(0.0, campfire_heat_seconds - maxf(0.0, delta))
    _campfire_save_accumulator += maxf(0.0, delta)
    if _campfire_save_accumulator >= 1.0 or campfire_heat_seconds <= 0.0:
        _campfire_save_accumulator = 0.0
        _persist_campfire_state()
    if campfire_heat_seconds <= 0.0:
        set_process(false)

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
        "B05_TOWNHALL":
            _build_townhall()
        "B06_SHRINE":
            _build_shrine()
        "B07_WATCHTOWER":
            _build_watchtower()
        "B08_GARDEN":
            _build_garden()
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
    var roof_panel_half_span := (HOUSE_WIDTH * 0.5 + 0.25) * 0.5
    var roof_center_x := roof_panel_half_span * cos(roof_angle)
    var roof_center_y := HOUSE_WALL_HEIGHT + roof_panel_half_span * sin(roof_angle) + 0.08
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



func _build_townhall() -> void:
    var foundation := _material(Color(0.24, 0.25, 0.26), 0.82)
    var stone := _material(Color(0.36, 0.38, 0.39))
    var stone_light := _material(Color(0.48, 0.49, 0.48))
    var wood := _material(Color(0.30, 0.17, 0.075))
    var trim := _material(Color(0.15, 0.10, 0.06))
    var roof := _material(Color(0.10, 0.13, 0.15), 0.72)
    var roof_light := _material(Color(0.16, 0.19, 0.21), 0.72)
    var glass := _emissive_material(Color(0.20, 0.48, 0.52), 0.6)
    var metal := _material(Color(0.22, 0.24, 0.25), 0.38, 0.7)
    var banner := _emissive_material(Color(0.08, 0.46, 0.52), 0.8)

    _mesh_box(Vector3(8.0, 0.24, 7.0), Vector3(0, 0.12, 0), foundation)
    _mesh_box(Vector3(7.4, 2.6, 6.4), Vector3(0, 1.42, 0), stone)

    # Timber frame and central civic tower.
    _mesh_box(Vector3(7.65, 0.22, 0.24), Vector3(0, 2.65, -3.25), wood)
    _mesh_box(Vector3(7.65, 0.22, 0.24), Vector3(0, 2.65, 3.25), wood)
    _mesh_box(Vector3(0.24, 0.22, 6.5), Vector3(-3.55, 2.65, 0), wood)
    _mesh_box(Vector3(0.24, 0.22, 6.5), Vector3(3.55, 2.65, 0), wood)
    _mesh_box(Vector3(3.0, 4.2, 3.0), Vector3(0, 3.55, 0), stone_light)

    # Four roof planes form a compact hip roof. Each panel slopes toward the
    # tower center; the overlap keeps the crown visually continuous from every side.
    var roof_angle := deg_to_rad(35.0)
    var roof_y := 5.95
    _mesh_box(Vector3(2.35, 0.20, 3.55), Vector3(-0.82, roof_y, 0), roof, Vector3(0, 0, roof_angle))
    _mesh_box(Vector3(2.35, 0.20, 3.55), Vector3(0.82, roof_y, 0), roof, Vector3(0, 0, -roof_angle))
    _mesh_box(Vector3(3.55, 0.20, 2.35), Vector3(0, roof_y, -0.82), roof_light, Vector3(roof_angle, 0, 0))
    _mesh_box(Vector3(3.55, 0.20, 2.35), Vector3(0, roof_y, 0.82), roof_light, Vector3(-roof_angle, 0, 0))

    # Front civic entrance and steps.
    var front_z := -3.32
    _mesh_box(Vector3(2.1, 0.22, 1.25), Vector3(0, 0.11, front_z - 0.58), foundation)
    _mesh_box(Vector3(2.5, 2.25, 0.22), Vector3(0, 1.25, front_z), wood)
    _mesh_box(Vector3(1.65, 2.0, 0.16), Vector3(0, 1.05, front_z - 0.13), trim)
    _mesh_box(Vector3(1.25, 1.75, 0.10), Vector3(0, 1.0, front_z - 0.22), glass)

    for x in [-2.55, 2.55]:
        for y in [1.35, 2.35]:
            _add_window(Vector3(x, y, -3.36), Vector3.ZERO, glass, trim)

    for x in [-0.86, 0.86]:
        _mesh_box(Vector3(0.58, 0.82, 0.10), Vector3(x, 4.15, -1.54), glass)
    _mesh_cylinder(0.18, 0.42, Vector3(0, 6.70, 0), metal, 8)
    _mesh_sphere(0.20, Vector3(0, 6.98, 0), metal)
    _mesh_box(Vector3(1.0, 1.45, 0.06), Vector3(0, 3.45, front_z - 0.15), banner)

    _add_box_collision(Vector3(7.4, 2.6, 6.4), Vector3(0, 1.42, 0))
    _add_box_collision(Vector3(3.0, 4.2, 3.0), Vector3(0, 3.55, 0))


func _add_window(position_value: Vector3, rotation_value: Vector3, glass: Material, frame: Material) -> void:
    var basis := Basis.from_euler(rotation_value)
    var glass_panel := glass
    if glass is StandardMaterial3D:
        glass_panel = glass.duplicate()
        glass_panel.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
        glass_panel.cull_mode = BaseMaterial3D.CULL_DISABLED
        glass_panel.roughness = 0.32
        glass_panel.metallic = 0.05
    _mesh_box(Vector3(0.95, 0.85, 0.12), position_value, glass_panel, rotation_value)
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


func _build_shrine() -> void:
	var stone := _material(Color(0.25, 0.30, 0.31), 0.9)
	var lux := _emissive_material(Color(0.08, 0.62, 0.68), 1.4)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		_mesh_cylinder(0.20, 0.35, Vector3(cos(angle) * 0.9, 0.18, sin(angle) * 0.9), stone, 6)
	_mesh_cylinder(0.78, 0.18, Vector3(0, 0.48, 0), stone, 8)
	_mesh_cylinder(0.30, 1.8, Vector3(0, 1.38, 0), lux, 7)
	_mesh_sphere(0.34, Vector3(0, 2.34, 0), lux, Vector3(0.75, 1.25, 0.75))
	_add_box_collision(Vector3(1.8, 0.8, 1.8), Vector3(0, 0.4, 0))

func _build_watchtower() -> void:
	var wood := _material(Color(0.30, 0.17, 0.075))
	var dark := _material(Color(0.12, 0.10, 0.075))
	var roof := _material(Color(0.11, 0.15, 0.16), 0.75)
	for x in [-0.95, 0.95]:
		for z in [-0.95, 0.95]:
			_mesh_box(Vector3(0.18, 4.4, 0.18), Vector3(x, 2.2, z), wood)
	_mesh_box(Vector3(2.25, 0.18, 2.25), Vector3(0, 3.9, 0), wood)
	_mesh_box(Vector3(2.5, 0.18, 2.5), Vector3(0, 4.35, 0), roof)
	_mesh_cylinder(0.11, 1.2, Vector3(0, 4.95, 0), dark, 6)
	_mesh_sphere(0.16, Vector3(0, 5.58, 0), _emissive_material(Color(0.10, 0.48, 0.52), 0.7))
	_add_box_collision(Vector3(2.1, 4.0, 2.1), Vector3(0, 2.0, 0))

func _build_garden() -> void:
	var soil := _material(Color(0.20, 0.14, 0.08))
	var wood := _material(Color(0.29, 0.16, 0.07))
	var plant := _emissive_material(Color(0.18, 0.52, 0.32), 0.45)
	var lux := _emissive_material(Color(0.08, 0.48, 0.55), 0.8)
	_mesh_box(Vector3(3.6, 0.16, 3.6), Vector3(0, 0.08, 0), soil)
	for x in [-1.2, -0.4, 0.4, 1.2]:
		_mesh_box(Vector3(0.16, 0.28, 3.0), Vector3(x, 0.25, 0), wood)
	for z in [-1.1, -0.35, 0.35, 1.1]:
		_mesh_sphere(0.15, Vector3(-0.8, 0.43, z), plant, Vector3(0.7, 1.4, 0.7))
		_mesh_sphere(0.13, Vector3(0.8, 0.46, z), lux, Vector3(0.7, 1.7, 0.7))
	_add_box_collision(Vector3(3.6, 0.22, 3.6), Vector3(0, 0.11, 0))


func _build_generic() -> void:
    var material := _material(Color(0.35, 0.28, 0.18))
    _mesh_box(Vector3(2.0, 1.5, 2.0), Vector3(0, 0.75, 0), material)
    _add_box_collision(Vector3(2.0, 1.5, 2.0), Vector3(0, 0.75, 0))
