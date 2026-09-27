extends Node
class_name VeyraSettlementManager

## Lightweight settlement state.
## Distant villagers are represented as data; full agents can be spawned later
## only when the player is close enough to require them.

signal settlement_changed

const SETTLEMENT_VERSION := 1

var settlement_name: String = "New Settlement"
var population: int = 0
var food_stock: int = 0
var water_stock: int = 0
var wood_stock: int = 0
var stone_stock: int = 0

var buildings: Dictionary = {}
var villagers: Dictionary = {}

func _ready() -> void:
    add_to_group("settlement_manager")

func initialize(name_value: String = "New Settlement") -> void:
    settlement_name = name_value
    settlement_changed.emit()

func add_building(building_id: String, building_type: String, position: Vector3) -> bool:
    if building_id.is_empty() or buildings.has(building_id):
        return false
    buildings[building_id] = {
        "id": building_id,
        "type": building_type,
        "position": [position.x, position.y, position.z],
        "condition": 1.0,
        "door_open": false,
        "storage": {}
    }
    settlement_changed.emit()
    return true

func set_building_door_state(building_id: String, open: bool) -> bool:
    if not buildings.has(building_id):
        return false
    var record: Dictionary = buildings[building_id]
    record["door_open"] = open
    buildings[building_id] = record
    settlement_changed.emit()
    return true


func get_building_storage(building_id: String) -> Dictionary:
    if not buildings.has(building_id):
        return {}
    var record: Dictionary = buildings[building_id]
    var storage = record.get("storage", {})
    return storage.duplicate(true) if storage is Dictionary else {}

func set_building_storage(building_id: String, storage: Dictionary) -> bool:
    if not buildings.has(building_id):
        return false
    var record: Dictionary = buildings[building_id]
    record["storage"] = storage.duplicate(true)
    buildings[building_id] = record
    settlement_changed.emit()
    return true

func get_building_record(building_id: String) -> Dictionary:
    var record = buildings.get(building_id, {})
    return record.duplicate(true) if record is Dictionary else {}

func add_villager(villager_id: String, name_value: String = "Villager") -> bool:
    if villager_id.is_empty() or villagers.has(villager_id):
        return false
    villagers[villager_id] = {
        "id": villager_id,
        "name": name_value,
        "job": "Unassigned",
        "health": 1.0,
        "food": 1.0,
        "water": 1.0,
        "morale": 1.0,
        "active": false
    }
    population = villagers.size()
    settlement_changed.emit()
    return true

func assign_job(villager_id: String, job: String) -> bool:
    if not villagers.has(villager_id):
        return false
    villagers[villager_id]["job"] = job
    settlement_changed.emit()
    return true

func add_stock(resource_type: String, amount: int) -> void:
    if amount <= 0:
        return
    match resource_type:
        "Food":
            food_stock += amount
        "Water":
            water_stock += amount
        "Wood":
            wood_stock += amount
        "Stone":
            stone_stock += amount
    settlement_changed.emit()

func get_settlement_state() -> Dictionary:
    return {
        "version": SETTLEMENT_VERSION,
        "name": settlement_name,
        "population": population,
        "stock": {
            "food": food_stock,
            "water": water_stock,
            "wood": wood_stock,
            "stone": stone_stock
        },
        "buildings": buildings.duplicate(true),
        "villagers": villagers.duplicate(true)
    }

func load_settlement_state(state: Dictionary) -> void:
    if state.is_empty():
        return
    settlement_name = str(state.get("name", settlement_name))
    var stock: Dictionary = state.get("stock", {})
    food_stock = maxi(0, int(stock.get("food", 0)))
    water_stock = maxi(0, int(stock.get("water", 0)))
    wood_stock = maxi(0, int(stock.get("wood", 0)))
    stone_stock = maxi(0, int(stock.get("stone", 0)))
    buildings = state.get("buildings", {}).duplicate(true)
    villagers = state.get("villagers", {}).duplicate(true)
    population = villagers.size()
    settlement_changed.emit()
