extends StaticBody3D
class_name VeyraBuildingInstance

var building_id: String = ""
var building_type: String = ""

func setup(id: String, type_id: String, position_value: Vector3) -> void:
	building_id = id
	building_type = type_id
	global_position = position_value
	collision_layer = 2
	collision_mask = 1
	_build_visual()

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()

	match building_type:
		"B01_CAMPFIRE":
			_build_campfire()
		"B02_STORAGE":
			_build_crate()
		"B03_SHELTER":
			_build_shelter()
		"B04_WELL":
			_build_well()
		_:
			_build_generic()

func _mesh_box(size: Vector3, position_value: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _mesh_cylinder(radius: float, height: float, position_value: Vector3, material: Material, segments: int = 8) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _add_box_collision(size: Vector3, position_value: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_value
	add_child(collision)

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_campfire() -> void:
	var stone := _material(Color(0.28, 0.30, 0.32))
	var ember := _material(Color(0.55, 0.16, 0.05), 0.7)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		_mesh_cylinder(0.22, 0.22, Vector3(cos(angle) * 0.7, 0.11, sin(angle) * 0.7), stone, 6)
	_mesh_cylinder(0.32, 0.32, Vector3(0, 0.16, 0), ember, 7)

func _build_crate() -> void:
	var wood := _material(Color(0.34, 0.20, 0.09))
	_mesh_box(Vector3(1.7, 1.2, 1.7), Vector3(0, 0.6, 0), wood)
	_add_box_collision(Vector3(1.7, 1.2, 1.7), Vector3(0, 0.6, 0))

func _build_shelter() -> void:
	var wood := _material(Color(0.30, 0.18, 0.08))
	var roof := _material(Color(0.12, 0.14, 0.16))
	_mesh_box(Vector3(0.25, 2.4, 3.8), Vector3(-2.35, 1.2, 0), wood)
	_mesh_box(Vector3(0.25, 2.4, 3.8), Vector3(2.35, 1.2, 0), wood)
	_mesh_box(Vector3(4.7, 0.25, 3.8), Vector3(0, 2.4, 0), roof)
	_add_box_collision(Vector3(0.35, 2.4, 3.8), Vector3(-2.35, 1.2, 0))
	_add_box_collision(Vector3(0.35, 2.4, 3.8), Vector3(2.35, 1.2, 0))
	_add_box_collision(Vector3(4.7, 0.25, 3.8), Vector3(0, 2.4, 0))

func _build_well() -> void:
	var stone := _material(Color(0.30, 0.32, 0.34))
	var dark := _material(Color(0.08, 0.09, 0.10))
	_mesh_cylinder(1.15, 0.8, Vector3(0, 0.4, 0), stone, 10)
	_mesh_cylinder(0.72, 0.05, Vector3(0, 0.83, 0), dark, 10)
	_add_box_collision(Vector3(2.2, 0.8, 2.2), Vector3(0, 0.4, 0))

func _build_generic() -> void:
	var material := _material(Color(0.35, 0.28, 0.18))
	_mesh_box(Vector3(2, 1.5, 2), Vector3(0, 0.75, 0), material)
	_add_box_collision(Vector3(2, 1.5, 2), Vector3(0, 0.75, 0))
