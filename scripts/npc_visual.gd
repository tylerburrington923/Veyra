class_name NPCVisual
extends Node3D

## Lightweight humanoid NPC presentation.
## Owns only meshes/presentation; never stores authoritative NPC gameplay state.

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

	_add_limb("LeftArm", Vector3(-0.40, 1.14, 0.0), Vector3(0.0, 0.0, -8.0), skin)
	_add_limb("RightArm", Vector3(0.40, 1.14, 0.0), Vector3(0.0, 0.0, 8.0), skin)
	_add_limb("LeftLeg", Vector3(-0.18, 0.48, 0.0), Vector3.ZERO, pants)
	_add_limb("RightLeg", Vector3(0.18, 0.48, 0.0), Vector3.ZERO, pants)
	_add_foot("LeftFoot", Vector3(-0.18, 0.08, -0.08), pants)
	_add_foot("RightFoot", Vector3(0.18, 0.08, -0.08), pants)

func _add_limb(node_name: String, node_position: Vector3, degrees: Vector3, material: StandardMaterial3D) -> void:
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
