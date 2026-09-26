extends Node3D

## Veyra world coordinator.
## The world is permanently nocturnal; lunar phase replaces seasons/daylight.
## The world seed remains authoritative for all deterministic generators.

@export var lunar_cycle_seconds: float = 900.0
@export var default_world_seed: int = 47291

var world_time: float = 0.0
var world_seed: int = 47291
var has_loaded_save := false

@onready var lunar_cycle: VeyraLunarCycle = get_node_or_null("LunarCycle") as VeyraLunarCycle

func _ready() -> void:
    world_seed = default_world_seed

    if GameManager:
        world_seed = GameManager.world_seed
        _apply_loaded_state(GameManager.get_loaded_save())

    _apply_seed_to_generators()

    if lunar_cycle:
        lunar_cycle.cycle_length_seconds = lunar_cycle_seconds
        lunar_cycle.configure(world_seed, world_time)

    print("Veyra world initialized. Seed: ", world_seed, " | Lunar phase: ", lunar_cycle.get_phase_name() if lunar_cycle else "Unavailable")


func _process(delta: float) -> void:
    if lunar_cycle:
        lunar_cycle.advance(delta)
        world_time = lunar_cycle.world_time


func _apply_loaded_state(save_data: Dictionary) -> void:
    if save_data.is_empty():
        return

    var saved_world: Dictionary = save_data.get("world", {})
    if not saved_world.is_empty():
        world_time = maxf(0.0, float(saved_world.get("world_time", 0.0)))

    var settlement_state: Dictionary = save_data.get("settlement", {})
    if SettlementManager and not settlement_state.is_empty():
        SettlementManager.load_settlement_state(settlement_state)

    var inventory_state: Dictionary = save_data.get("inventory", {})
    var player := get_tree().get_first_node_in_group("local_player")
    if player and player.has_method("get_inventory"):
        var inventory := player.get_inventory()
        if inventory:
            inventory.load_snapshot(inventory_state)

    has_loaded_save = true


func _apply_seed_to_generators() -> void:
    var generator := get_node_or_null("WorldGenerator")
    if generator:
        generator.seed_value = world_seed

    var foliage := get_node_or_null("Foliage")
    if foliage:
        foliage.seed_value = world_seed

    var detail := get_node_or_null("WorldDetail")
    if detail:
        detail.seed_value = world_seed


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
        "version": 3
    }

func save_game() -> bool:
    if not GameManager:
        return false
    return GameManager.save_current_game(self)
