class_name NPCVisual
extends Node3D

## Lightweight humanoid NPC presentation.
## Owns only meshes/presentation; never stores authoritative NPC gameplay state.

var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var gait_phase := 0.0

func configure(definition: NPCDefinition) -> void:
	_clear_visual()
	if definition == null:
		return

	var shirt := _make_material(_color_for_archetype(definition.visual_archetype), 0.84)
	var pants := _make_material(Color(0.055, 0.065, 0.075, 1), 0.88)
	var skin := _make_material(Color(0.72, 0.50, 0.36, 1), 0.86)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.29
	body_mesh.height = 0.78
	body_mesh.radial_segments = 8
	body.mesh = body_mesh
	body.material_override = shirt
	body.position = Vector3(0.0, 1.15, 0.0)
	body.scale = Vector3(1.06, 1.04, 0.88)
	add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28
	head_mesh.height = 0.56
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0.0, 1.78, 0.0)
	head.scale = Vector3(0.96, 1.02, 0.94)
	add_child(head)

	left_arm = _add_limb("LeftArm", Vector3(-0.40, 1.14, 0.0), Vector3(0.0, 0.0, -8.0), skin)
	right_arm = _add_limb("RightArm", Vector3(0.40, 1.14, 0.0), Vector3(0.0, 0.0, 8.0), skin)
	left_leg = _add_limb("LeftLeg", Vector3(-0.18, 0.48, 0.0), Vector3.ZERO, pants)
	right_leg = _add_limb("RightLeg", Vector3(0.18, 0.48, 0.0), Vector3.ZERO, pants)
	_add_foot("LeftFoot", Vector3(-0.18, 0.08, -0.08), pants)
	_add_foot("RightFoot", Vector3(0.18, 0.08, -0.08), pants)

func set_motion(speed_ratio: float, delta: float) -> void:
	var intensity := clampf(speed_ratio, 0.0, 1.0)
	if intensity < 0.03:
		intensity = 0.0
		gait_phase = lerpf(gait_phase, 0.0, 1.0 - exp(-8.0 * delta))
	else:
		gait_phase = fmod(gait_phase + delta * (7.0 + 5.0 * intensity), TAU)
	var swing := sin(gait_phase) * deg_to_rad(20.0) * intensity
	if left_arm: left_arm.rotation.x = swing
	if right_arm: right_arm.rotation.x = -swing
	if left_leg: left_leg.rotation.x = -swing * 0.9
	if right_leg: right_leg.rotation.x = swing * 0.9

func _add_limb(node_name: String, node_position: Vector3, degrees: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	limb.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.75
	mesh.radial_segments = 6
	limb.mesh = mesh
	limb.material_override = material
	limb.position = node_position
	limb.rotation_degrees = degrees
	add_child(limb)
	return limb

func _add_foot(node_name: String, node_position: Vector3, material: StandardMaterial3D) -> void:
	var foot := MeshInstance3D.new()
	foot.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 6
	mesh.rings = 3
	foot.mesh = mesh
	foot.material_override = material
	foot.position = node_position
	foot.scale = Vector3(1.0, 0.55, 1.25)
	add_child(foot)

func _make_material(color: Color, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	return material

func _clear_visual() -> void:
	left_arm = null
	right_arm = null
	left_leg = null
	right_leg = null
	gait_phase = 0.0
	for child in get_children():
		child.queue_free()

func _color_for_archetype(archetype: String) -> Color:
	match archetype:
		"worker_01":
			return Color(0.22, 0.40, 0.52, 1)
		"villager_01":
			return Color(0.52, 0.36, 0.24, 1)
		_:
			return Color(0.42, 0.46, 0.50, 1)
