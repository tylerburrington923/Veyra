extends Node
class_name VeyraBuildingManager

signal placement_changed(building_id: String, valid: bool, position: Vector3)
signal building_completed(building_id: String, position: Vector3)

const BUILDING_VERSION := 1
const MIN_BUILD_DISTANCE := 1.5
const MAX_BUILD_DISTANCE := 8.0
const GRID_SIZE := 1.0

var selected_building_id: String = ""
var placement_position := Vector3.ZERO
var placement_valid := false
var placement_location_valid := false
var placement_active := false
var preview: MeshInstance3D
var building_root: Node3D

func _ready() -> void:
    add_to_group("building_manager")
    building_completed.connect(_on_building_completed)
    call_deferred("_initialize_building_root")

func select_building(building_id: String) -> bool:
    if not VeyraBuildingCatalog.exists(building_id):
        selected_building_id = ""
        _clear_preview()
        return false
    selected_building_id = building_id
    placement_active = true
    _ensure_preview()
    _refresh_preview_mesh()
    return true

func cancel_placement() -> void:
    selected_building_id = ""
    placement_active = false
    placement_valid = false
    placement_location_valid = false
    _clear_preview()
    placement_changed.emit("", false, placement_position)

func get_selected_building() -> Dictionary:
    return VeyraBuildingCatalog.get_building(selected_building_id)

func update_from_camera(player: Node3D, camera: Camera3D, inventory: VeyraInventory) -> void:
    if not placement_active or not camera or not player:
        return
    var ray_origin := camera.global_position
    var ray_end := ray_origin + -camera.global_transform.basis.z * MAX_BUILD_DISTANCE
    # Placement is driven by terrain, never by the roof/walls of an existing
    # building. Existing structures are still checked separately by
    # _is_space_clear(), so aiming at a building cannot place a new one on top
    # of it or make the player appear to "jump" onto it.
    var terrain_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
    terrain_query.collide_with_bodies = true
    terrain_query.collide_with_areas = false
    if player is CollisionObject3D:
        terrain_query.exclude = [player.get_rid()]
    var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(terrain_query)
    var point: Vector3 = hit.get("position", ray_end) if not hit.is_empty() else ray_end
    point.y = _ground_height(point, player)
    evaluate_placement(player, point, inventory)

func evaluate_placement(player: Node3D, position: Vector3, inventory: VeyraInventory) -> bool:
    placement_position = snap_position(position)
    placement_valid = false
    placement_location_valid = false

    if not player or not inventory or selected_building_id.is_empty():
        _update_preview(false)
        placement_changed.emit(selected_building_id, false, placement_position)
        return false

    var definition := get_selected_building()
    if definition.is_empty():
        _update_preview(false)
        placement_changed.emit(selected_building_id, false, placement_position)
        return false

    var distance := player.global_position.distance_to(placement_position)
    if distance < MIN_BUILD_DISTANCE or distance > MAX_BUILD_DISTANCE:
        _update_preview(false)
        placement_changed.emit(selected_building_id, false, placement_position)
        return false

    placement_location_valid = _is_space_clear(placement_position, definition.get("size", Vector2.ONE), player)
    placement_valid = placement_location_valid and has_required_materials(inventory)
    _update_preview(placement_location_valid)
    placement_changed.emit(selected_building_id, placement_valid, placement_position)
    return placement_valid

func has_required_materials(inventory: VeyraInventory) -> bool:
    if not inventory or selected_building_id.is_empty():
        return false
    var definition := get_selected_building()
    for resource_type in definition.get("cost", {}).keys():
        if not inventory.has_resource(str(resource_type), int(definition["cost"][resource_type])):
            return false
    return true

func server_build(player: Node3D, building_id: String, requested_position: Vector3, inventory: VeyraInventory) -> bool:
    # Multiplayer requests must not mutate the shared client preview state. This
    # performs a complete authoritative validation/build transaction from the
    # request's own building id and position.
    if not player or not inventory or not VeyraBuildingCatalog.exists(building_id):
        return false
    var definition := VeyraBuildingCatalog.get_building(building_id)
    if definition.is_empty():
        return false
    var position := snap_position(requested_position)
    position.y = _ground_height(position, player)
    var distance := player.global_position.distance_to(position)
    if distance < MIN_BUILD_DISTANCE or distance > MAX_BUILD_DISTANCE:
        return false
    if not _is_space_clear(position, definition.get("size", Vector2.ONE), player):
        return false
    if building_id == "B05_TOWNHALL" and _has_townhall():
        return false
    for resource_type in definition.get("cost", {}).keys():
        var amount := int(definition["cost"][resource_type])
        if not inventory.has_resource(str(resource_type), amount):
            return false
    var settlement := _get_settlement_manager()
    if not settlement:
        return false
    var building_id_value := _next_building_id()
    var cost: Dictionary = definition.get("cost", {})
    for resource_type in cost.keys():
        var amount := int(cost[resource_type])
        if inventory.remove_resource(str(resource_type), amount) < amount:
            for rollback_type in cost.keys():
                inventory.add_resource(str(rollback_type), int(cost[rollback_type]))
            return false
    if not bool(settlement.call("add_building", building_id_value, building_id, position)):
        for rollback_type in cost.keys():
            inventory.add_resource(str(rollback_type), int(cost[rollback_type]))
        return false
    _spawn_building_visual(building_id_value, building_id, position)
    building_completed.emit(building_id, position)
    return true

func confirm_build(player: Node3D, inventory: VeyraInventory) -> bool:
    if not placement_valid or selected_building_id.is_empty():
        return false

    var definition := get_selected_building()
    # There is one civic anchor per settlement. A Town Hall can be built only
    # when the settlement does not already contain one.
    if selected_building_id == "B05_TOWNHALL" and _has_townhall():
        return false
    var cost: Dictionary = definition.get("cost", {})
    for resource_type in cost.keys():
        if inventory.remove_resource(str(resource_type), int(cost[resource_type])) < int(cost[resource_type]):
            return false

    var building_id := _next_building_id()
    var settlement := _get_settlement_manager()
    if not settlement or not bool(settlement.call("add_building", building_id, selected_building_id, placement_position)):
        for resource_type in cost.keys():
            inventory.add_resource(str(resource_type), int(cost[resource_type]))
        return false

    _spawn_building_visual(building_id, selected_building_id, placement_position)
    building_completed.emit(selected_building_id, placement_position)
    placement_valid = false
    placement_location_valid = false
    placement_active = false
    _clear_preview()
    return true

func snap_position(position: Vector3) -> Vector3:
    return Vector3(snappedf(position.x, GRID_SIZE), position.y, snappedf(position.z, GRID_SIZE))

func _ground_height(position: Vector3, player: Node3D) -> float:
    var origin := position + Vector3.UP * 8.0
    var end := position + Vector3.DOWN * 8.0
    var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
    if player is CollisionObject3D:
        query.exclude = [player.get_rid()]
    var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return position.y
    return float(hit.get("position", position).y)

func _is_space_clear(position: Vector3, size: Vector2, player: Node3D) -> bool:
    var state := get_viewport().get_world_3d().direct_space_state
    var shape := BoxShape3D.new()
    shape.size = Vector3(maxf(0.5, size.x), 1.5, maxf(0.5, size.y))
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.75)
    # Terrain is the placement surface, not an obstacle. Only test existing
    # world/building bodies on layer 2 for footprint collisions.
    query.collision_mask = 2 | 4
    query.collide_with_bodies = true
    query.collide_with_areas = true
    if player is CollisionObject3D:
        query.exclude = [player.get_rid()]
    return state.intersect_shape(query, 1).is_empty()

func _ensure_preview() -> void:
    if preview:
        return
    preview = MeshInstance3D.new()
    preview.name = "BuildingPreview"
    preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    get_tree().current_scene.add_child(preview)

func _refresh_preview_mesh() -> void:
    if not preview:
        return
    var definition := get_selected_building()
    var size: Vector2 = definition.get("size", Vector2.ONE)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(size.x, 1.5, size.y)
    preview.mesh = mesh
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.2, 0.85, 0.45, 0.38)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    preview.material_override = material

func _update_preview(valid: bool) -> void:
    if not preview:
        return
    preview.visible = placement_active
    preview.position = placement_position + Vector3.UP * 0.75
    var material := preview.material_override as StandardMaterial3D
    if material:
        material.albedo_color = Color(0.2, 0.85, 0.45, 0.38) if valid else Color(0.9, 0.22, 0.18, 0.38)

func _clear_preview() -> void:
    if preview:
        preview.queue_free()
        preview = null

func _next_building_id() -> String:
    var settlement := _get_settlement_manager()
    var buildings: Dictionary = settlement.get("buildings") if settlement else {}
    var index := buildings.size() + 1
    var candidate := "B-%04d" % index
    while buildings.has(candidate):
        index += 1
        candidate = "B-%04d" % index
    return candidate

func _initialize_building_root() -> void:
    if building_root:
        return
    building_root = Node3D.new()
    building_root.name = "PlacedBuildings"
    var parent: Node = get_tree().current_scene
    if not parent:
        parent = get_tree().root
    parent.add_child(building_root)

func restore_from_settlement() -> void:
    _initialize_building_root()
    for child in building_root.get_children():
        child.queue_free()
    var settlement := _get_settlement_manager()
    if not settlement:
        return
    var buildings: Dictionary = settlement.get("buildings")
    for building_id in buildings.keys():
        var record: Dictionary = buildings[building_id]
        var position_data = record.get("position", [0.0, 0.0, 0.0])
        if position_data is Array and position_data.size() >= 3:
            var position_value := Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
            _spawn_building_visual(
                str(building_id),
                str(record.get("type", "")),
                position_value,
                bool(record.get("door_open", false))
            )

func _spawn_building_visual(
    building_id: String,
    building_type: String,
    position_value: Vector3,
    door_open: bool = false
) -> void:
    _initialize_building_root()
    var instance := VeyraBuildingInstance.new()
    instance.name = building_id
    building_root.add_child(instance)
    instance.setup(building_id, building_type, position_value, door_open)
    instance.door_state_changed.connect(_on_door_state_changed)

func _on_building_completed(building_id: String, _position: Vector3) -> void:
    var progression := get_node_or_null("/root/ProgressionManager")
    if progression and progression.has_method("record_action"):
        progression.call("record_action", "BUILD", 1, building_id)

func _on_door_state_changed(building_id: String, open: bool) -> void:
    var settlement := _get_settlement_manager()
    if settlement:
        settlement.call("set_building_door_state", building_id, open)

func _has_townhall() -> bool:
    var settlement := _get_settlement_manager()
    if not settlement:
        return false
    var buildings: Dictionary = settlement.get("buildings")
    for record in buildings.values():
        if record is Dictionary and str(record.get("type", "")) == "B05_TOWNHALL":
            return true
    return false

func _get_settlement_manager() -> Node:
    return get_node_or_null("/root/SettlementManager")


func get_save_state() -> Dictionary:
    return {
        "version": BUILDING_VERSION,
        "selected": selected_building_id
    }
