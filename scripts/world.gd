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

func _ready() -> void:
	world_seed = default_world_seed

	if GameManager:
		world_seed = GameManager.world_seed
		_apply_loaded_state(GameManager.get_loaded_save())

	_apply_seed_to_generators()

	if lunar_cycle:
		lunar_cycle.cycle_length_seconds = lunar_cycle_seconds
		lunar_cycle.configure(world_seed, world_time)

	call_deferred("_restore_buildings")
	print("Veyra world initialized. Seed: ", world_seed, " | Lunar phase: ", lunar_cycle.get_phase_name() if lunar_cycle else "Unavailable")


func _process(delta: float) -> void:
	if lunar_cycle:
		lunar_cycle.advance(delta)
		world_time = lunar_cycle.world_time
	if SettlementManager and SettlementManager.has_method("process_water_cycle"):
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

	var detail := get_node_or_null("WorldDetail")
	if detail:
		detail.set("seed_value", world_seed)

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
		"version": 5
	}

func _get_resource_state() -> Dictionary:
	var generator := get_node_or_null("WorldGenerator")
	if generator and generator.has_method("get_resource_state"):
		return generator.get_resource_state()
	return {}

func save_game() -> bool:
	if not GameManager:
		return false
	return GameManager.save_current_game(self)


func _restore_buildings() -> void:
	if BuildingManager and BuildingManager.has_method("restore_from_settlement"):
		BuildingManager.restore_from_settlement()

func _ensure_wildlife_manager() -> void:
	if get_node_or_null("AnimalManager"):
		return
	var manager := ANIMAL_MANAGER_SCRIPT.new()
	manager.name = "AnimalManager"
	add_child(manager)
