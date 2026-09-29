extends StaticBody3D
class_name VeyraBuildSiteInstance

var site_id: String = ""
var manager: VeyraBuildSiteManager
var _last_feedback := ""

func setup(id: String, p_manager: VeyraBuildSiteManager) -> void:
	site_id = id
	manager = p_manager
	collision_layer = 2
	collision_mask = 1
	add_to_group("interactable")
	_build_visual()

func can_interact(player: Node = null) -> bool:
	if not manager or not manager.has_site(site_id):
		return false
	if not player or not player is Node3D:
		return false
	return (player as Node3D).global_position.distance_to(global_position) <= VeyraBuildSiteManager.MAX_PLAYER_DEPOSIT_DISTANCE

func get_interaction_point() -> Vector3:
	return global_position + Vector3.UP * 0.35

func get_interaction_name() -> String:
	var site := manager.get_site(site_id) if manager else {}
	var definition := VeyraBuildingCatalog.get_building(str(site.get("building_type", "")))
	return "%s Foundation" % str(definition.get("name", "Building"))

func get_interaction_text() -> String:
	return "DEPOSIT MATERIALS"

func get_interaction_requirement(_player: Node) -> String:
	return "BUILD SITE RANGE"

func get_interaction_feedback() -> String:
	return _last_feedback

func interact(player: Node = null) -> void:
	if not manager or not player:
		return
	var remaining := manager.get_remaining_materials(site_id)
	if remaining.is_empty():
		_last_feedback = "Foundation is ready for completion."
		return
	var deposited := manager.deposit_from_player(site_id, player)
	if deposited:
		var after := manager.get_remaining_materials(site_id)
		_last_feedback = "Materials delivered. %s" % _format_materials(after)
	else:
		_last_feedback = "Carry required materials to the foundation. %s" % _format_materials(remaining)

func _build_visual() -> void:
	var site := manager.get_site(site_id) if manager else {}
	var definition := VeyraBuildingCatalog.get_building(str(site.get("building_type", "")))
	var size: Vector2 = definition.get("size", Vector2(2.0, 2.0))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.12, size.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.34, 0.18, 1.0)
	material.roughness = 0.92
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position.y = 0.06
	add_child(instance)

	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(size.x * 0.92, 0.04, size.y * 0.92)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.72, 0.56, 0.26, 1.0)
	marker_material.roughness = 0.95
	var marker := MeshInstance3D.new()
	marker.mesh = marker_mesh
	marker.material_override = marker_material
	marker.position.y = 0.13
	add_child(marker)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.25, size.y)
	collision.shape = shape
	collision.position.y = 0.12
	add_child(collision)

func _format_materials(resources: Dictionary) -> String:
	if resources.is_empty():
		return "ALL MATERIALS DELIVERED"
	var parts: Array[String] = []
	for key in resources.keys():
		parts.append("%s %d" % [str(key), int(resources[key])])
	return "REMAINING: " + " • ".join(parts)
