extends Node

## Central runtime state for Veyra.
## World seed and loaded save data are established before the world generates.

var is_host := true
var local_player_id := 1
var world_seed: int = 47291
var loaded_save: Dictionary = {}

func _ready() -> void:
    if SaveManager:
        loaded_save = SaveManager.load_world()
        var saved_world: Dictionary = loaded_save.get("world", {})
        if not saved_world.is_empty():
            world_seed = int(saved_world.get("seed", world_seed))

func start_host() -> void:
    is_host = true
    print("Veyra host started. World seed: ", world_seed)

func start_client() -> void:
    is_host = false
    print("Veyra client mode selected.")

func get_session_info() -> Dictionary:
    return {
        "is_host": is_host,
        "local_player_id": local_player_id,
        "world_seed": world_seed
    }

func get_loaded_save() -> Dictionary:
    return loaded_save.duplicate(true)

func clear_loaded_save() -> void:
    loaded_save.clear()

func save_current_game(world: Node) -> bool:
    if not world:
        return false

    var player := get_tree().get_first_node_in_group("local_player")
    if not player or not player.has_method("get_inventory"):
        return false

    var inventory := player.get_inventory()
    if not inventory:
        return false

    var settlement_state := {}
    if SettlementManager:
        settlement_state = SettlementManager.get_settlement_state()

    if not SaveManager:
        return false

    var saved := SaveManager.save_world(world, inventory.get_snapshot(), settlement_state)
    if saved:
        loaded_save = SaveManager.load_world()
    return saved
