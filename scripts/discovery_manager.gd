extends Node3D
class_name VeyraDiscoveryManager

const SITE_SCRIPT = preload("res://scripts/discovery_site.gd")

var sites: Array[Node] = []
var _initialized := false

func _ready() -> void:
	add_to_group("discovery_manager")
	call_deferred("_initialize")

func _initialize() -> void:
	if _initialized:
		return
	var world_generator := get_parent().get_node_or_null("WorldGenerator")
	if not world_generator:
		return
	if world_generator.has_method("is_generated") and not world_generator.is_generated():
		call_deferred("_initialize")
		return
	_spawn_sites(world_generator)
	_initialized = true

func _spawn_sites(world_generator: Node) -> void:
	# The original landmark is the first archaeological site. Two additional
	# deterministic traces give exploration a meaningful early-world loop.
	var definitions := [
		["ANCIENT_LANDMARK", "Ancient Resonance Marker", Vector3(0.0, 0.0, -18.0), 10.0],
		["ANCIENT_TRACE_EAST", "Buried Stone Trace", Vector3(34.0, 0.0, 8.0), 8.0],
		["ANCIENT_TRACE_WEST", "Collapsed Resonance Cairn", Vector3(-31.0, 0.0, 27.0), 8.0]
	]
	for definition in definitions:
		var site := SITE_SCRIPT.new()
		site.name = str(definition[0])
		add_child(site)
		var p: Vector3 = definition[2]
		if world_generator.has_method("get_height_at_world"):
			p.y = float(world_generator.get_height_at_world(p.x, p.z)) + 1.0
		site.configure(str(definition[0]), str(definition[1]), p)
		site.exploration_radius = float(definition[3])
		sites.append(site)
		_build_visual(site, str(definition[0]))

func _build_visual(site: Node3D, id: String) -> void:
	if id == "ANCIENT_LANDMARK":
		return
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.24, 0.27, 0.28, 1)
	stone_material.roughness = 0.92
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.06, 0.38, 0.42, 1)
	accent.emission_enabled = true
	accent.emission = Color(0.02, 0.18, 0.21, 1)
	accent.emission_energy_multiplier = 0.8
	for i in range(4):
		var rock := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.65, 1.2 + float(i % 2) * 0.35, 0.65)
		rock.mesh = mesh
		rock.material_override = stone_material
		var angle := TAU * float(i) / 4.0
		rock.position = Vector3(cos(angle) * 0.75, mesh.size.y * 0.5, sin(angle) * 0.75)
		rock.rotation.y = angle
		site.add_child(rock)
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.12
	core_mesh.bottom_radius = 0.18
	core_mesh.height = 0.75
	core.mesh = core_mesh
	core.material_override = accent
	core.position = Vector3(0, 0.9, 0)
	site.add_child(core)
