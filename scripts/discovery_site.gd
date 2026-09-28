extends StaticBody3D
class_name VeyraDiscoverySite

@export var discovery_id := ""
@export var display_name := "Ancient Site"
@export var exploration_radius := 10.0
@export var archaeology_xp_subject := "ANCIENT_LANDMARK"

var _explored := false
var _examined := false
var _proximity_accumulator := 0.0
const PROXIMITY_CHECK_INTERVAL := 0.25

func configure(id_value: String, name_value: String, position_value: Vector3) -> void:
	discovery_id = id_value
	display_name = name_value
	global_position = position_value

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	shape.shape = sphere
	add_child(shape)
	_sync_persistent_state()
	set_process(true)

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_proximity_accumulator += delta
	if _proximity_accumulator < PROXIMITY_CHECK_INTERVAL:
		return
	_proximity_accumulator = 0.0
	var player := get_tree().get_first_node_in_group("local_player") as Node3D
	if not player or discovery_id.is_empty():
		return
	if player.global_position.distance_to(global_position) <= exploration_radius:
		var progression := get_node_or_null("/root/ProgressionManager")
		if progression and progression.has_method("record_unique_action"):
			if progression.record_unique_action("EXPLORE", archaeology_xp_subject, discovery_id):
				_explored = true

func can_interact(_player: Node) -> bool:
	_sync_persistent_state()
	return not _examined

func get_interaction_point() -> Vector3:
	return global_position + Vector3.UP * 1.0

func get_interaction_name() -> String:
	return display_name

func get_interaction_text() -> String:
	return "EXAMINE SITE"

func get_interaction_requirement(_player: Node) -> String:
	return ""

func interact(player_override: Node = null) -> void:
	_sync_persistent_state()
	if _examined:
		return
	var player := player_override if player_override else get_tree().get_first_node_in_group("local_player")
	if not player:
		return
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("record_unique_action"):
		progression.record_unique_action("ARCHAEOLOGY", archaeology_xp_subject, discovery_id)
	_examined = true
	set_process(false)

func _sync_persistent_state() -> void:
	var progression := get_node_or_null("/root/ProgressionManager")
	if not progression or discovery_id.is_empty():
		return
	if progression.has_method("has_discovered"):
		_explored = progression.has_discovered(discovery_id, "EXPLORE")
		_examined = progression.has_discovered(discovery_id, "ARCHAEOLOGY")

func get_discovery_state() -> Dictionary:
	return {"id": discovery_id, "explored": _explored, "examined": _examined}
