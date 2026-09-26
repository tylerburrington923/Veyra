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

func _ready() -> void:
	add_to_group("building_manager")

func select_building(building_id: String) -> bool:
	if not VeyraBuildingCatalog.exists(building_id):
		selected_building_id = ""
		return false
	selected_building_id = building_id
	return true

func get_selected_building() -> Dictionary:
	return VeyraBuildingCatalog.get_building(selected_building_id)

func snap_position(position: Vector3) -> Vector3:
	return Vector3(
		snappedf(position.x, GRID_SIZE),
		position.y,
		snappedf(position.z, GRID_SIZE)
	)

func evaluate_placement(player: Node3D, position: Vector3, inventory: VeyraInventory) -> bool:
	placement_position = snap_position(position)
	placement_valid = false

	if not player or not inventory or selected_building_id.is_empty():
		placement_changed.emit(selected_building_id, false, placement_position)
		return false

	var definition := get_selected_building()
	if definition.is_empty():
		placement_changed.emit(selected_building_id, false, placement_position)
		return false

	var distance := player.global_position.distance_to(placement_position)
	if distance < MIN_BUILD_DISTANCE or distance > MAX_BUILD_DISTANCE:
		placement_changed.emit(selected_building_id, false, placement_position)
		return false

	var cost: Dictionary = definition.get("cost", {})
	for resource_type in cost.keys():
		if not inventory.has_resource(str(resource_type), int(cost[resource_type])):
			placement_changed.emit(selected_building_id, false, placement_position)
			return false

	placement_valid = _is_space_clear(placement_position, definition.get("size", Vector2.ONE), player)
	placement_changed.emit(selected_building_id, placement_valid, placement_position)
	return placement_valid

func confirm_build(player: Node3D, inventory: VeyraInventory) -> bool:
	if not placement_valid or selected_building_id.is_empty():
		return false

	var definition := get_selected_building()
	var cost: Dictionary = definition.get("cost", {})
	for resource_type in cost.keys():
		if inventory.remove_resource(str(resource_type), int(cost[resource_type])) < int(cost[resource_type]):
			return false

	var building_id := _next_building_id()
	if not SettlementManager.add_building(building_id, selected_building_id, placement_position):
		for resource_type in cost.keys():
			inventory.add_resource(str(resource_type), int(cost[resource_type]))
		return false

	building_completed.emit(selected_building_id, placement_position)
	placement_valid = false
	return true

func _is_space_clear(position: Vector3, size: Vector2, player: Node3D) -> bool:
	var state := get_viewport().get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(0.5, size.x), 1.5, maxf(0.5, size.y))

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.75)
	query.collision_mask = 1 | 2
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	return state.intersect_shape(query, 1).is_empty()

func _next_building_id() -> String:
	var index := SettlementManager.buildings.size() + 1
	var candidate := "B-%04d" % index
	while SettlementManager.buildings.has(candidate):
		index += 1
		candidate = "B-%04d" % index
	return candidate

func get_save_state() -> Dictionary:
	return {
		"version": BUILDING_VERSION,
		"selected": selected_building_id
	}
