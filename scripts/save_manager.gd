extends Node

const SAVE_PATH := "user://veyra_world.json"
const BACKUP_PATH := "user://veyra_world.backup.json"
const SAVE_VERSION := 5

func save_world(world: Node, inventory: Dictionary, settlement: Dictionary = {}, player_state: Dictionary = {}) -> bool:
    if not world or not world.has_method("get_world_state"):
        return false

    var payload := {
        "version": SAVE_VERSION,
        "world": world.get_world_state(),
        "inventory": _sanitize_inventory(inventory),
        "settlement": _sanitize_settlement(settlement),
        "player": _sanitize_player_state(player_state)
    }
    var json := JSON.stringify(payload)

    if FileAccess.file_exists(SAVE_PATH):
        var current := _read_text_file(SAVE_PATH)
        if not current.is_empty() and not _write_file(BACKUP_PATH, current):
            return false

    return _write_file(SAVE_PATH, json)

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

    if not (data.get("player", {}) is Dictionary):
        data["player"] = {}
    data["player"] = _sanitize_player_state(data["player"])

    if not (data.get("settlement", {}) is Dictionary):
        data["settlement"] = {}
    data["settlement"] = _sanitize_settlement(data["settlement"])
    return data

func _write_file(path: String, json: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(json)
    file.close()
    return true

func _read_text_file(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var text := file.get_as_text()
    file.close()
    return text

func _read_file(path: String) -> Dictionary:
    var text := _read_text_file(path)
    if text.is_empty():
        return {}
    var parsed = JSON.parse_string(text)
    return parsed if parsed is Dictionary else {}

func _sanitize_inventory(inventory: Dictionary) -> Dictionary:
    var clean := {
        "resources": {},
        "items": {}
    }
    if inventory.is_empty():
        return clean

    var resources = inventory.get("resources", inventory)
    if resources is Dictionary:
        for key in resources.keys():
            var value = resources[key]
            if key is String and (value is int or value is float) and int(value) > 0 and VeyraResourceCatalog.is_valid(key):
                clean["resources"][key] = int(value)

    var items = inventory.get("items", {})
    if items is Dictionary:
        for key in items.keys():
            var value = items[key]
            if key is String and (value is int or value is float) and int(value) > 0 and VeyraItemCatalog.is_valid(key):
                clean["items"][key] = int(value)

    return clean

func _sanitize_player_state(player_state: Dictionary) -> Dictionary:
    if player_state.is_empty():
        return {"tool_id": "T00_HANDS", "tool_durability": 100.0}
    var tool_id := str(player_state.get("tool_id", "T00_HANDS"))
    if tool_id != "T00_HANDS" and tool_id not in VeyraItemCatalog.TOOL_IDS:
        tool_id = "T00_HANDS"
    return {
        "tool_id": tool_id,
        "tool_durability": clampf(float(player_state.get("tool_durability", 100.0)), 0.0, 100.0)
    }

func _sanitize_settlement(settlement: Dictionary) -> Dictionary:
    if settlement.is_empty():
        return {}

    var clean := {
        "version": maxi(1, int(settlement.get("version", 1))),
        "name": str(settlement.get("name", "New Settlement")),
        "population": maxi(0, int(settlement.get("population", 0))),
        "stock": {},
        "buildings": {},
        "villagers": {}
    }

    var stock = settlement.get("stock", {})
    if stock is Dictionary:
        for key in ["food", "water", "wood", "stone"]:
            clean["stock"][key] = maxi(0, int(stock.get(key, 0)))

    var buildings = settlement.get("buildings", {})
    if buildings is Dictionary:
        for building_id in buildings.keys():
            var record = buildings[building_id]
            if not (record is Dictionary):
                continue
            var clean_record := {
                "id": str(record.get("id", building_id)),
                "type": str(record.get("type", "")),
                "position": [],
                "condition": clampf(float(record.get("condition", 1.0)), 0.0, 1.0),
                "door_open": bool(record.get("door_open", false)),
                "storage": {
                    "resources": {},
                    "items": {}
                }
            }
            var position = record.get("position", [])
            if position is Array and position.size() >= 3:
                clean_record["position"] = [
                    float(position[0]),
                    float(position[1]),
                    float(position[2])
                ]
            else:
                clean_record["position"] = [0.0, 0.0, 0.0]

            var storage = record.get("storage", {})
            if storage is Dictionary:
                var stored_resources = storage.get("resources", {})
                if stored_resources is Dictionary:
                    for key in stored_resources.keys():
                        var value = stored_resources[key]
                        if key is String and (value is int or value is float) and int(value) > 0 and VeyraResourceCatalog.is_valid(key):
                            clean_record["storage"]["resources"][key] = int(value)
                var stored_items = storage.get("items", {})
                if stored_items is Dictionary:
                    for key in stored_items.keys():
                        var value = stored_items[key]
                        if key is String and (value is int or value is float) and int(value) > 0 and VeyraItemCatalog.is_valid(key):
                            clean_record["storage"]["items"][key] = int(value)
            clean["buildings"][str(building_id)] = clean_record

    var villagers = settlement.get("villagers", {})
    if villagers is Dictionary:
        clean["villagers"] = villagers.duplicate(true)

    return clean
