class_name NPCController
extends Node3D

## Presentation/controller boundary for an authoritative NPCState.
## This node may read authoritative state and interpolate visuals, but never
## becomes the owner of gameplay state.

@export var position_smoothing: float = 12.0
@export var rotation_smoothing: float = 12.0

var authoritative_state: NPCState
var definition: NPCDefinition
var visual: NPCVisual

func _ready() -> void:
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
		global_position = _state_position(authoritative_state.position)
		rotation = _state_rotation(authoritative_state.rotation)

func _process(delta: float) -> void:
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

func _state_rotation(data: Dictionary) -> Quaternion:
	var euler := Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)
	return Quaternion.from_euler(euler)
