class_name NPCVisual
extends Node3D

## Lightweight NPC presentation.
## Owns only meshes/presentation; never stores authoritative NPC gameplay state.

func configure(definition: NPCDefinition) -> void:
	_clear_visual()
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = _color_for_archetype(definition.visual_archetype)
	body_material.roughness = 0.9

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.24
	body_mesh.height = 1.0
	body_mesh.radial_segments = 6
	body.mesh = body_mesh
	body.material_override = body_material
	body.position = Vector3(0.0, 0.55, 0.0)
	add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head_mesh.radial_segments = 6
	head_mesh.rings = 3
	head.mesh = head_mesh
	head.material_override = body_material
	head.position = Vector3(0.0, 1.28, 0.0)
	add_child(head)

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
