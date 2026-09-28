class_name NPCVisual
extends Node3D

## Lightweight humanoid NPC presentation.
## Owns only meshes/presentation; never stores authoritative NPC gameplay state.
## Deliberately uses simple low-poly parts, but with readable clothing, face and proportions.

var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_forearm: MeshInstance3D
var right_forearm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_sleeve: MeshInstance3D
var right_sleeve: MeshInstance3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var left_sleeve_pivot: Node3D
var right_sleeve_pivot: Node3D
var gait_phase := 0.0
var torso: MeshInstance3D
var head: MeshInstance3D

func configure(definition: NPCDefinition) -> void:
	_clear_visual()
	if definition == null:
		return

	var shirt_color := _color_for_archetype(definition.visual_archetype)
	var shirt := _make_material(shirt_color, 0.84)
	var shirt_dark := _make_material(shirt_color.darkened(0.18), 0.88)
	var pants := _make_material(Color(0.055, 0.065, 0.075, 1), 0.88)
	var boot := _make_material(Color(0.045, 0.040, 0.035, 1), 0.94)
	var skin := _make_material(Color(0.62, 0.40, 0.28, 1), 0.86)
	var skin_light := _make_material(Color(0.70, 0.47, 0.34, 1), 0.86)
	var hair_material := _make_material(Color(0.025, 0.028, 0.032, 1), 0.95)
	var eye_white := _make_material(Color(0.78, 0.86, 0.84, 1), 0.38)
	var eye_dark := _make_material(Color(0.025, 0.045, 0.048, 1), 0.42)
	var accent := _make_material(Color(0.16, 0.58, 0.58, 1), 0.68, 0.0, true, 0.30)
	var belt_material := _make_material(Color(0.075, 0.060, 0.050, 1), 0.92)
	var buckle := _make_material(Color(0.48, 0.40, 0.20, 1), 0.42, 0.55)

	torso = _capsule("Body", Vector3(0.0, 1.17, 0.0), 0.29, 0.88, shirt, 8)
	torso.scale = Vector3(1.02, 1.04, 0.88)

	var hem := _capsule("TunicHem", Vector3(0.0, 0.79, 0.0), 0.285, 0.22, shirt_dark, 8)
	hem.scale = Vector3(1.02, 0.78, 0.88)

	_mesh_cylinder("Neck", 0.115, 0.16, Vector3(0.0, 1.59, 0.0), skin_light, 7)

	head = _sphere("Head", Vector3(0.0, 1.86, 0.0), 0.28, skin, 8)
	head.scale = Vector3(0.95, 1.02, 0.92)

	var hair := _sphere("Hair", Vector3(0.0, 2.045, 0.015), 0.285, hair_material, 8)
	hair.scale = Vector3(1.02, 0.40, 1.00)
	_sphere("HairLeft", Vector3(-0.23, 1.94, 0.02), 0.11, hair_material, 6)
	_sphere("HairRight", Vector3(0.23, 1.94, 0.02), 0.11, hair_material, 6)

	_sphere("EarLeft", Vector3(-0.275, 1.85, -0.005), 0.075, skin_light, 6, Vector3(0.72, 1.0, 0.72))
	_sphere("EarRight", Vector3(0.275, 1.85, -0.005), 0.075, skin_light, 6, Vector3(0.72, 1.0, 0.72))
	_sphere("Nose", Vector3(0.0, 1.79, -0.285), 0.055, skin_light, 6, Vector3(0.62, 0.82, 0.62))
	_mesh_box("Mouth", Vector3(0.09, 0.025, 0.025), Vector3(0.0, 1.685, -0.274), eye_dark)

	var eye_left := _add_eye("LeftEye", Vector3(-0.095, 1.86, -0.255), eye_white, eye_dark)
	var eye_right := _add_eye("RightEye", Vector3(0.095, 1.86, -0.255), eye_white, eye_dark)
	add_child(eye_left)
	add_child(eye_right)

	_mesh_box("Belt", Vector3(0.62, 0.12, 0.46), Vector3(0.0, 0.89, 0.0), belt_material)
	_mesh_box("Buckle", Vector3(0.10, 0.10, 0.055), Vector3(0.0, 0.89, -0.245), buckle)

	left_sleeve_pivot = _limb_pivot("LeftSleevePivot", Vector3(-0.39, 1.22, 0.0), Vector3(0.0, 0.0, -8.0))
	right_sleeve_pivot = _limb_pivot("RightSleevePivot", Vector3(0.39, 1.22, 0.0), Vector3(0.0, 0.0, 8.0))
	left_sleeve = _capsule_child("LeftSleeve", Vector3(0.0, 0.0, 0.0), 0.13, 0.48, shirt, 7, left_sleeve_pivot)
	right_sleeve = _capsule_child("RightSleeve", Vector3(0.0, 0.0, 0.0), 0.13, 0.48, shirt, 7, right_sleeve_pivot)

	left_arm_pivot = _limb_pivot("LeftArmPivot", Vector3(-0.40, 1.22, 0.0), Vector3(0.0, 0.0, -8.0))
	right_arm_pivot = _limb_pivot("RightArmPivot", Vector3(0.40, 1.22, 0.0), Vector3(0.0, 0.0, 8.0))
	left_arm = _capsule_child("LeftArm", Vector3(0.0, -0.31, 0.0), 0.095, 0.40, skin, 6, left_arm_pivot)
	right_arm = _capsule_child("RightArm", Vector3(0.0, -0.31, 0.0), 0.095, 0.40, skin, 6, right_arm_pivot)
	left_forearm = left_arm
	right_forearm = right_arm
	_sphere_child("LeftHand", Vector3(0.0, -0.56, 0.0), 0.105, skin_light, 7, left_arm_pivot)
	_sphere_child("RightHand", Vector3(0.0, -0.56, 0.0), 0.105, skin_light, 7, right_arm_pivot)

	left_leg_pivot = _limb_pivot("LeftLegPivot", Vector3(-0.18, 0.84, 0.0), Vector3.ZERO)
	right_leg_pivot = _limb_pivot("RightLegPivot", Vector3(0.18, 0.84, 0.0), Vector3.ZERO)
	left_leg = _capsule_child("LeftLeg", Vector3(0.0, -0.39, 0.0), 0.115, 0.82, pants, 6, left_leg_pivot)
	right_leg = _capsule_child("RightLeg", Vector3(0.0, -0.39, 0.0), 0.115, 0.82, pants, 6, right_leg_pivot)
	_add_foot_child("LeftFoot", Vector3(0.0, -0.76, -0.10), boot, left_leg_pivot)
	_add_foot_child("RightFoot", Vector3(0.0, -0.76, -0.10), boot, right_leg_pivot)
	_mesh_box_child("LeftSole", Vector3(0.23, 0.07, 0.42), Vector3(0.0, -0.805, -0.12), boot, left_leg_pivot)
	_mesh_box_child("RightSole", Vector3(0.23, 0.07, 0.42), Vector3(0.0, -0.805, -0.12), boot, right_leg_pivot)

func set_motion(speed_ratio: float, delta: float) -> void:
	var intensity := clampf(speed_ratio, 0.0, 1.0)
	if intensity < 0.03:
		intensity = 0.0
		gait_phase = lerpf(gait_phase, 0.0, 1.0 - exp(-8.0 * delta))
	else:
		gait_phase = fmod(gait_phase + delta * (7.0 + 5.0 * intensity), TAU)
	var swing := sin(gait_phase) * deg_to_rad(20.0) * intensity
	if left_sleeve_pivot: left_sleeve_pivot.rotation.x = swing * 0.75
	if right_sleeve_pivot: right_sleeve_pivot.rotation.x = -swing * 0.75
	if left_arm_pivot: left_arm_pivot.rotation.x = swing
	if right_arm_pivot: right_arm_pivot.rotation.x = -swing
	if left_leg_pivot: left_leg_pivot.rotation.x = -swing * 0.9
	if right_leg_pivot: right_leg_pivot.rotation.x = swing * 0.9

func _sphere_child(node_name: String, node_position: Vector3, radius: float, material: StandardMaterial3D, segments: int, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	instance.position = node_position
	parent.add_child(instance)
	return instance

func _add_foot_child(node_name: String, node_position: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
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
	foot.scale = Vector3(0.95, 0.55, 1.30)
	parent.add_child(foot)
	return foot

func _mesh_box_child(node_name: String, size: Vector3, node_position: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = node_position
	parent.add_child(instance)
	return instance

func _limb_pivot(node_name: String, node_position: Vector3, initial_rotation_degrees: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = node_position
	pivot.rotation_degrees = initial_rotation_degrees
	add_child(pivot)
	return pivot

func _capsule_child(node_name: String, node_position: Vector3, radius: float, height: float, material: StandardMaterial3D, segments: int, parent: Node3D) -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	limb.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	limb.mesh = mesh
	limb.material_override = material
	limb.position = node_position
	parent.add_child(limb)
	return limb

func _capsule(node_name: String, node_position: Vector3, radius: float, height: float, material: StandardMaterial3D, segments: int) -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	limb.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	limb.mesh = mesh
	limb.material_override = material
	limb.position = node_position
	add_child(limb)
	return limb

func _mesh_cylinder(node_name: String, radius: float, height: float, node_position: Vector3, material: StandardMaterial3D, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.material_override = material
	instance.position = node_position
	add_child(instance)
	return instance

func _mesh_box(node_name: String, size: Vector3, node_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = node_position
	add_child(instance)
	return instance

func _sphere(node_name: String, node_position: Vector3, radius: float, material: StandardMaterial3D, segments: int = 7, scale_value := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	instance.position = node_position
	instance.scale = scale_value
	add_child(instance)
	return instance

func _add_eye(node_name: String, node_position: Vector3, white: StandardMaterial3D, pupil: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var eye := MeshInstance3D.new()
	eye.name = "Sclera"
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.042
	eye_mesh.height = 0.084
	eye_mesh.radial_segments = 6
	eye_mesh.rings = 3
	eye.mesh = eye_mesh
	eye.material_override = white
	eye.position = node_position
	eye.scale = Vector3(1.0, 1.12, 0.58)
	root.add_child(eye)
	var pupil_instance := MeshInstance3D.new()
	pupil_instance.name = "Pupil"
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.021
	pupil_mesh.height = 0.042
	pupil_mesh.radial_segments = 5
	pupil_mesh.rings = 3
	pupil_instance.mesh = pupil_mesh
	pupil_instance.material_override = pupil
	pupil_instance.position = node_position + Vector3(0.0, 0.0, -0.035)
	pupil_instance.scale = Vector3(1.0, 1.1, 0.42)
	root.add_child(pupil_instance)
	return root

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
	foot.scale = Vector3(0.95, 0.55, 1.30)
	add_child(foot)

func _make_material(color: Color, roughness_value: float, metallic_value: float = 0.0, emission_enabled: bool = false, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	material.metallic = metallic_value
	if emission_enabled:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material

func _clear_visual() -> void:
	left_arm = null
	right_arm = null
	left_forearm = null
	right_forearm = null
	left_leg = null
	right_leg = null
	left_sleeve = null
	right_sleeve = null
	left_arm_pivot = null
	right_arm_pivot = null
	left_leg_pivot = null
	right_leg_pivot = null
	left_sleeve_pivot = null
	right_sleeve_pivot = null
	gait_phase = 0.0
	for child in get_children():
		child.queue_free()

func _color_for_archetype(archetype: String) -> Color:
	match archetype:
		"worker_01":
			return Color(0.24, 0.38, 0.46, 1)
		"villager_01":
			return Color(0.46, 0.30, 0.20, 1)
		_:
			return Color(0.34, 0.40, 0.44, 1)
