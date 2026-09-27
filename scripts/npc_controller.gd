class_name NPCController
extends StaticBody3D

## Presentation/controller boundary for an authoritative NPCState.
## This node may read authoritative state and interpolate visuals, but never
## becomes the owner of gameplay state.

@export var position_smoothing: float = 12.0
@export var rotation_smoothing: float = 12.0

var authoritative_state: NPCState
var definition: NPCDefinition
var visual: NPCVisual
var interaction_cooldown := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("interactable")
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.88, 0.0)
	add_child(shape)
	visual = NPCVisual.new()
	visual.name = "Visual"
	add_child(visual)

func configure(p_definition: NPCDefinition, p_state: NPCState) -> void:
	definition = p_definition
	authoritative_state = p_state
	if visual and definition:
		visual.configure(definition)
	if authoritative_state:
		global_position = _state_position(authoritative_state.position)
		rotation = _state_rotation(authoritative_state.rotation)

func apply_authoritative_state(p_state: NPCState) -> void:
	authoritative_state = p_state
	if not authoritative_state:
		return
	if not is_inside_tree():
		return

func _process(delta: float) -> void:
	interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
	if not authoritative_state or not authoritative_state.alive:
		return

	var target_position := _state_position(authoritative_state.position)
	var target_rotation := _state_rotation(authoritative_state.rotation)
	var position_weight := 1.0 - exp(-maxf(0.0, position_smoothing) * delta)
	var rotation_weight := 1.0 - exp(-maxf(0.0, rotation_smoothing) * delta)

	global_position = global_position.lerp(target_position, position_weight)
	rotation = rotation.slerp(target_rotation, rotation_weight)

func _state_position(data: Dictionary) -> Vector3:
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)

func _state_rotation(data: Dictionary) -> Vector3:
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)

func can_interact(player: Node = null) -> bool:
	if interaction_cooldown > 0.0:
		return false
	if player and player is Node3D and global_position.distance_to((player as Node3D).global_position) > 5.0:
		return false
	return authoritative_state != null and authoritative_state.alive

func get_interaction_text() -> String:
	return "TALK"

func get_interaction_point() -> Vector3:
	return global_position + Vector3.UP * 1.0

func get_interaction_feedback() -> String:
	if authoritative_state:
		return "VILLAGER • %s" % (authoritative_state.current_job if not authoritative_state.current_job.is_empty() else "IDLE")
	return "VILLAGER"

func interact(player: Node = null) -> void:
	if not can_interact(player):
		return
	interaction_cooldown = 0.6
