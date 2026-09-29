extends Node

## Central runtime state for Veyra.
## Keeps the authoritative world seed and the pending save payload available
## before the world and its deterministic generators initialize.

var world_seed: int = 47291
var loaded_save: Dictionary = {}

func _ready() -> void:
    if SaveManager:
        loaded_save = SaveManager.load_world()
        var saved_world: Dictionary = loaded_save.get("world", {})
        if not saved_world.is_empty():
            world_seed = int(saved_world.get("seed", world_seed))
    var progression := get_node_or_null("/root/ProgressionManager")
    if progression and progression.has_method("load_save_state"):
        progression.load_save_state(loaded_save.get("progression", {}))
    var logistics := get_node_or_null("/root/BuildSiteManager")
    if logistics and logistics.has_method("load_save_state"):
        logistics.load_save_state(loaded_save.get("logistics", {}))

func get_loaded_save() -> Dictionary:
    return loaded_save.duplicate(true)

func save_current_game(world: Node) -> bool:
    if not world:
        return false

    var player: Node = get_tree().get_first_node_in_group("local_player")
    if not player or not player.has_method("get_inventory"):
        return false

    var inventory: VeyraInventory = player.get_inventory()
    if not inventory or not SaveManager:
        return false

    var settlement_state := {}
    if SettlementManager:
        settlement_state = SettlementManager.get_settlement_state()

    var player_state: Dictionary = player.get_save_state() if player.has_method("get_save_state") else {}
    var progression_state := {}
    var progression := get_node_or_null("/root/ProgressionManager")
    if progression and progression.has_method("get_save_state"):
        progression_state = progression.get_save_state()
    var logistics_state := {}
    var logistics := get_node_or_null("/root/BuildSiteManager")
    if logistics and logistics.has_method("get_save_state"):
        logistics_state = logistics.get_save_state()
    var saved: bool = SaveManager.save_world(world, inventory.get_snapshot(), settlement_state, player_state, progression_state, logistics_state)
    if saved:
        loaded_save = SaveManager.load_world()
    return saved
