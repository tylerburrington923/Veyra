extends Node

const SAVE_PATH := "user://veyra_world.json"
const BACKUP_PATH := "user://veyra_world.backup.json"
const SAVE_VERSION := 2

func save_world(world: Node, inventory: Dictionary) -> bool:
    if not world or not world.has_method("get_world_state"):
        return false

    var payload := {
        "version": SAVE_VERSION,
        "world": world.get_world_state(),
        "inventory": _sanitize_inventory(inventory)
    }
    var json := JSON.stringify(payload)

    if not _write_file(BACKUP_PATH, json):
        return false
    if not _write_file(SAVE_PATH, json):
        return false
    return true

func load_world() -> Dictionary:
    var data := _read_file(SAVE_PATH)
    if data.is_empty():
        data = _read_file(BACKUP_PATH)
    if data.is_empty():
        return {}

    var version := int(data.get("version", 0))
    if version < 1 or version > SAVE_VERSION:
        return {}

    if not (data.get("world", {}) is Dictionary):
        return {}
    if not (data.get("inventory", {}) is Dictionary):
        data["inventory"] = {}
    data["inventory"] = _sanitize_inventory(data["inventory"])
    return data

func _write_file(path: String, json: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(json)
    file.close()
    return true

func _read_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    return parsed if parsed is Dictionary else {}

func _sanitize_inventory(inventory: Dictionary) -> Dictionary:
    var clean := {}
    for key in inventory.keys():
        var value = inventory[key]
        if key is String and value is int and value > 0:
            clean[key] = value
    return clean
