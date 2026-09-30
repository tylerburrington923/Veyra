extends Node3D

## Veyra world coordinator.
## The world is permanently nocturnal; lunar phase replaces seasons/daylight.
## The world seed remains authoritative for all deterministic generators.

@export var lunar_cycle_seconds: float = 900.0
@export var default_world_seed: int = 47291

var world_time: float = 0.0
var world_seed: int = 47291

@onready var lunar_cycle: VeyraLunarCycle = get_node_or_null("LunarCycle") as VeyraLunarCycle
const ANIMAL_MANAGER_SCRIPT = preload("res://scripts/animal_manager.gd")
const DISCOVERY_MANAGER_SCRIPT = preload("res://scripts/discovery_manager.gd")

func _ready() -> void:
	world_seed = default_world_seed
	_apply_graphics_profile()

	if GameManager:
		world_seed = GameManager.world_seed
		_apply_loaded_state(GameManager.get_loaded_save())

	_apply_seed_to_generators()

	if lunar_cycle:
		lunar_cycle.cycle_length_seconds = lunar_cycle_seconds
		lunar_cycle.configure(world_seed, world_time)

	call_deferred("_restore_buildings")
	call_deferred("_restore_build_sites")
	call_deferred("_align_anomalies_to_terrain")
	call_deferred("_ensure_wildlife_manager")
	call_deferred("_ensure_discovery_manager")
	print("Veyra world initialized. Seed: ", world_seed, " | Lunar phase: ", lunar_cycle.get_phase_name() if lunar_cycle else "Unavailable")


func _process(delta: float) -> void:
	if lunar_cycle:
		lunar_cycle.advance(delta)
		world_time = lunar_cycle.world_time
	var network_manager = get_node_or_null("/root/NetworkManager")
	var simulate_settlement := network_manager == null or not bool(network_manager.get("session_active")) or bool(network_manager.get("is_host"))
	if simulate_settlement and SettlementManager and SettlementManager.has_method("process_water_cycle"):
		SettlementManager.process_water_cycle(world_time, lunar_cycle_seconds)


func _apply_loaded_state(save_data: Dictionary) -> void:
	if save_data.is_empty():
		return

	var saved_world: Dictionary = save_data.get("world", {})
	if not saved_world.is_empty():
		world_time = maxf(0.0, float(saved_world.get("world_time", 0.0)))
		var generator: Node = get_node_or_null("WorldGenerator")
		var resource_state = saved_world.get("resources", {})
		if generator and resource_state is Dictionary and generator.has_method("set_saved_resource_state"):
			generator.set_saved_resource_state(resource_state)
		var wildlife_manager := get_node_or_null("AnimalManager")
		var wildlife_state = saved_world.get("wildlife", [])
		if wildlife_manager and saved_world.has("wildlife") and wildlife_state is Array and wildlife_manager.has_method("set_saved_state"):
			wildlife_manager.set_saved_state(wildlife_state)

	var settlement_state: Dictionary = save_data.get("settlement", {})
	if SettlementManager and not settlement_state.is_empty():
		SettlementManager.load_settlement_state(settlement_state)

	var player: Node = get_tree().get_first_node_in_group("local_player")
	var inventory_state: Dictionary = save_data.get("inventory", {})
	if player and player.has_method("get_inventory"):
		var inventory: VeyraInventory = player.get_inventory()
		if inventory:
			inventory.load_snapshot(inventory_state)

	var player_state: Dictionary = save_data.get("player", {})
	if player and player.has_method("load_save_state") and player_state is Dictionary:
		player.load_save_state(player_state)


func _apply_seed_to_generators() -> void:
	var generator := get_node_or_null("WorldGenerator")
	if generator:
		generator.set("seed_value", world_seed)

	var foliage := get_node_or_null("Foliage")
	if foliage:
		foliage.set("seed_value", world_seed)


	var water := get_node_or_null("Water")
	if water:
		water.set("seed_value", world_seed)


func get_world_time() -> float:
	return world_time


func get_lunar_state() -> Dictionary:
	if lunar_cycle:
		return lunar_cycle.get_lunar_state()
	return {}


func get_world_state() -> Dictionary:
	return {
		"seed": world_seed,
		"world_time": world_time,
		"lunar": get_lunar_state(),
		"resources": _get_resource_state(),
		"wildlife": _get_wildlife_state(),
		"version": 6
	}

func _get_wildlife_state() -> Array:
	var manager := get_node_or_null("AnimalManager")
	if manager and manager.has_method("get_save_state"):
		return manager.get_save_state()
	return []

func _get_resource_state() -> Dictionary:
	var generator := get_node_or_null("WorldGenerator")
	if generator and generator.has_method("get_resource_state"):
		return generator.get_resource_state()
	return {}

func save_game() -> bool:
	if not GameManager:
		return false
	return GameManager.save_current_game(self)


func _align_anomalies_to_terrain() -> void:
	# Echo-Stone instances are authored at y=0, while the procedural terrain is not flat.
	# Ground them to the authoritative terrain height so anomalies never appear to float.
	var generator := get_node_or_null("WorldGenerator")
	if not generator or not generator.has_method("get_height_at_world"):
		return
	for node in get_children():
		if not node.name.begins_with("EchoStone"):
			continue
		var p := node.position
		p.y = float(generator.get_height_at_world(p.x, p.z)) + 0.9
		node.position = p
		# Echo-Stone owns its own material/emission state; terrain alignment only moves it.

func _restore_buildings() -> void:
	if BuildingManager and BuildingManager.has_method("restore_from_settlement"):
		BuildingManager.restore_from_settlement()

func _restore_build_sites() -> void:
	var logistics := get_node_or_null("/root/BuildSiteManager")
	if logistics and logistics.has_method("restore_presentations"):
		logistics.restore_presentations()

func _ensure_discovery_manager() -> void:
	if get_node_or_null("DiscoveryManager"):
		return
	var manager := DISCOVERY_MANAGER_SCRIPT.new()
	manager.name = "DiscoveryManager"
	add_child(manager)

func _ensure_wildlife_manager() -> void:
	if get_node_or_null("AnimalManager"):
		return
	var manager := ANIMAL_MANAGER_SCRIPT.new()
	manager.name = "AnimalManager"
	add_child(manager)

func apply_graphics_profile(profile_name: String) -> void:
	if not GraphicsSettings:
		return
	GraphicsSettings.profile = profile_name
	_apply_graphics_profile()

func _apply_graphics_profile() -> void:
	if not GraphicsSettings:
		return
	var camera := get_tree().get_first_node_in_group("local_player")
	if camera and camera.has_node("Camera3D"):
		camera.get_node("Camera3D").far = GraphicsSettings.get_camera_far()
	var foliage := get_node_or_null("Foliage")
	if foliage and foliage.has_method("set_visibility_distance"):
		foliage.set_visibility_distance(GraphicsSettings.get_foliage_distance())
	var environment := get_node_or_null("Environment")
	if environment and environment.environment:
		environment.environment.fog_density = GraphicsSettings.get_fog_density()
