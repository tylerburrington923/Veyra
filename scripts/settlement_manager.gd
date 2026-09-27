extends Node
class_name VeyraSettlementManager

## Lightweight settlement state.
## Distant villagers are represented as data; full agents can be spawned later
## only when the player is close enough to require them.

signal settlement_changed

const SETTLEMENT_VERSION := 2
const PLAYER_WATER_PER_CYCLE := 1
const VILLAGER_WATER_PER_CYCLE := 1

var settlement_name: String = "New Settlement"
var population: int = 0
var food_stock: int = 0
var water_stock: int = 0
var wood_stock: int = 0
var stone_stock: int = 0

var buildings: Dictionary = {}
var villagers: Dictionary = {}
var water_cycle_index: int = 0
var last_water_shortage: int = 0
var _last_world_time: float = 0.0
var _water_clock_initialized: bool = false

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

func get_active_player_count() -> int:
    return get_tree().get_nodes_in_group("player").size()

func get_active_villager_count() -> int:
    return villagers.size()

func get_water_demand() -> int:
    return get_active_player_count() * PLAYER_WATER_PER_CYCLE + get_active_villager_count() * VILLAGER_WATER_PER_CYCLE

func get_water_days_remaining() -> float:
    var demand: int = get_water_demand()
    if demand <= 0:
        return 0.0
    return float(water_stock) / float(demand)

func process_water_cycle(world_time: float, cycle_length_seconds: float) -> void:
    if cycle_length_seconds <= 0.0:
        return
    var normalized_time: float = fmod(maxf(0.0, world_time), cycle_length_seconds)
    if not _water_clock_initialized:
        _last_world_time = normalized_time
        _water_clock_initialized = true
        return
    if normalized_time >= _last_world_time:
        _last_world_time = normalized_time
        return
    _last_world_time = normalized_time
    water_cycle_index += 1
    var demand: int = get_water_demand()
    var required: int = demand
    var consumed: int = mini(water_stock, required)
    water_stock -= consumed
    last_water_shortage = maxi(0, required - consumed)
    settlement_changed.emit()

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
        "water_cycle_index": water_cycle_index,
        "water_shortage": last_water_shortage,
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
