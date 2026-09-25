extends Node

const SAVE_PATH := "user://veyra_world.json"

func save_world(world: Node, inventory: Dictionary) -> bool:
    if not world or not world.has_method("get_world_state"):
        return false

    var payload := {
        "version": 1,
        "world": world.get_world_state(),
        "inventory": inventory
    }

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false

    file.store_string(JSON.stringify(payload))
    file.close()
    return true

func load_world() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}

    var parsed = JSON.parse_string(file.get_as_text())
    file.close()

    return parsed if parsed is Dictionary else {}
