extends Node

## Central runtime state for Veyra.
## Kept small and deterministic so it can later be shared by host/server logic.

var is_host := true
var local_player_id := 1
var world_seed: int = 47291

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
