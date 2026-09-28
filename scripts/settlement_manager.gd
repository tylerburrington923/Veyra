extends Node
class_name VeyraSettlementManager

## Authoritative settlement state.
## Persistent settlement data stays here; production/job simulation uses the existing
## data-layer classes and never makes presentation nodes authoritative.

signal settlement_changed

const SETTLEMENT_VERSION := 3
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

var production_manager := ProductionManager.new()
var job_definitions: Dictionary = {}
var job_states: Dictionary = {}
var _next_job_index: int = 1

func _ready() -> void:
    add_to_group("settlement_manager")
    _register_economy_definitions()

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
        _:
            return
    settlement_changed.emit()

func consume_stock(resource_type: String, amount: int) -> bool:
    if amount <= 0:
        return false
    var available := 0
    match resource_type:
        "Food":
            available = food_stock
        "Water":
            available = water_stock
        "Wood":
            available = wood_stock
        "Stone":
            available = stone_stock
        _:
            return false
    if available < amount:
        return false
    match resource_type:
        "Food":
            food_stock -= amount
        "Water":
            water_stock -= amount
        "Wood":
            wood_stock -= amount
        "Stone":
            stone_stock -= amount
    settlement_changed.emit()
    return true

func _register_economy_definitions() -> void:
    production_manager.register_definition(ProductionDefinition.new(
        "gather_wood", {}, {"Wood": 2}, 6.0, "B02_STORAGE", "LUMBERJACK"
    ))
    production_manager.register_definition(ProductionDefinition.new(
        "cook_meat", {"Meat": 2, "Wood": 1}, {"Food": 3}, 8.0, "B01_CAMPFIRE", "COOK"
    ))
    production_manager.register_definition(ProductionDefinition.new(
        "refine_metal", {"Metal": 2, "Wood": 1}, {"Refined Metal": 1}, 12.0, "B09_BLACKSMITH", "BLACKSMITH"
    ))

    job_definitions["LUMBERJACK"] = JobDefinition.new(
        "LUMBERJACK", "Lumberjack", "RESOURCE", 1, ["human", "human_villager", "human_worker"],
        ["B02_STORAGE"], [], 6.0, "gather_wood", 3.0, 1.0
    )
    job_definitions["COOK"] = JobDefinition.new(
        "COOK", "Cook", "FOOD", 2, ["human", "human_villager", "human_worker"],
        ["B01_CAMPFIRE"], [], 8.0, "cook_meat", 3.0, 1.0
    )
    job_definitions["BLACKSMITH"] = JobDefinition.new(
        "BLACKSMITH", "Blacksmith", "CRAFT", 3, ["human", "human_villager", "human_worker"],
        ["B09_BLACKSMITH"], [], 12.0, "refine_metal", 3.0, 1.0
    )

func get_job_definition(job_id: String) -> JobDefinition:
    return job_definitions.get(job_id, null)

func get_villager_job(villager_id: String) -> JobState:
    return job_states.get(villager_id, null)

func _find_building_of_type(building_type: String) -> String:
    for building_id in buildings.keys():
        var record = buildings[building_id]
        if record is Dictionary and str(record.get("type", "")) == building_type:
            return str(building_id)
    return ""

func get_job_target_position(_job_id: String, building_id: String) -> Dictionary:
	return _get_building_position(building_id)

func _get_building_position(building_id: String) -> Dictionary:
    var record := get_building_record(building_id)
    var raw = record.get("position", [])
    if raw is Array and raw.size() >= 3:
        return NPCState.make_vector_dict(float(raw[0]), float(raw[1]), float(raw[2]))
    return NPCState.make_vector_dict()

func _get_primary_storage_id() -> String:
    return _find_building_of_type("B02_STORAGE")

func _get_primary_storage_resources() -> Dictionary:
    var storage_id := _get_primary_storage_id()
    if storage_id.is_empty():
        return {}
    var storage := get_building_storage(storage_id)
    var resources = storage.get("resources", {})
    return resources.duplicate(true) if resources is Dictionary else {}

func _set_primary_storage_resources(resources: Dictionary) -> bool:
    var storage_id := _get_primary_storage_id()
    if storage_id.is_empty():
        return false
    var storage := get_building_storage(storage_id)
    storage["resources"] = resources.duplicate(true)
    return set_building_storage(storage_id, storage)

func _choose_job_for_villager() -> Dictionary:
    var storage_id := _get_primary_storage_id()
    if storage_id.is_empty():
        return {}

    var resources := _get_primary_storage_resources()
    var blacksmith_id := _find_building_of_type("B09_BLACKSMITH")
    if not blacksmith_id.is_empty() and int(resources.get("Metal", 0)) >= 2 and int(resources.get("Wood", 0)) >= 1:
        return {"job_id": "BLACKSMITH", "building_id": blacksmith_id}

    var campfire_id := _find_building_of_type("B01_CAMPFIRE")
    if not campfire_id.is_empty() and int(resources.get("Meat", 0)) >= 2 and int(resources.get("Wood", 0)) >= 1:
        return {"job_id": "COOK", "building_id": campfire_id}

    return {"job_id": "LUMBERJACK", "building_id": storage_id}

func prepare_villager_job(villager_id: String) -> JobState:
    if not villagers.has(villager_id):
        return null
    var existing: JobState = job_states.get(villager_id, null)
    if existing != null and existing.active and not existing.completed:
        return existing

    var choice := _choose_job_for_villager()
    if choice.is_empty():
        return null
    var job_id := str(choice["job_id"])
    var definition: JobDefinition = job_definitions.get(job_id, null)
    if definition == null:
        return null
    var building_id := str(choice["building_id"])
    var storage := _get_primary_storage_resources()
    var production_id := "PROD-%04d" % _next_job_index
    var job_state_id := "JOB-%04d" % _next_job_index
    _next_job_index += 1

    var production_state := production_manager.start_production(
        production_id, definition.production_id, storage, building_id, villager_id
    )
    if production_state == null:
        return null
    if not _set_primary_storage_resources(storage):
        production_manager.complete_production(production_id, storage)
        return null

    var job_state := JobState.new(job_state_id, definition.id)
    job_state.assigned_worker_id = villager_id
    job_state.target_building_id = building_id
    job_state.active = true
    job_state.completed = false
    job_state.progress = 0.0
    job_states[villager_id] = job_state
    villagers[villager_id]["job"] = definition.id
    villagers[villager_id]["active"] = true
    settlement_changed.emit()
    return job_state

func sync_villager_job(villager_id: String, state: NPCState) -> bool:
    var job: JobState = job_states.get(villager_id, null)
    if job == null or not job.active or state == null or not state.alive:
        return false
    var definition: JobDefinition = job_definitions.get(job.definition_id, null)
    if definition == null:
        return false
    var production_id := ""
    for key in production_manager.get_active_productions().keys():
        var production: ProductionState = production_manager.get_active_productions()[key]
        if production != null and production.assigned_worker_id == villager_id:
            production_id = str(key)
            break
    if production_id.is_empty():
        return false
    if not production_manager.set_progress(production_id, job.progress):
        return false
    var production_state: ProductionState = production_manager.get_active_productions().get(production_id, null)
    if production_state == null:
        return false
    if not production_state.active:
        return false
    return true

func complete_villager_job(villager_id: String, state: NPCState) -> bool:
    var job: JobState = job_states.get(villager_id, null)
    if job == null or not job.active:
        return false
    var definition: JobDefinition = job_definitions.get(job.definition_id, null)
    if definition == null:
        return false
    var production_id := ""
    var active := production_manager.get_active_productions()
    for key in active.keys():
        var production: ProductionState = active[key]
        if production != null and production.assigned_worker_id == villager_id:
            production_id = str(key)
            break
    if production_id.is_empty():
        return false
    var production := active[production_id] as ProductionState
    if production == null:
        return false
    production_manager.set_progress(production_id, definition.work_duration)
    var storage := _get_primary_storage_resources()
    if not production_manager.complete_production(production_id, storage):
        return false
    if not _set_primary_storage_resources(storage):
        return false
    job.completed = true
    job.active = false
    if villagers.has(villager_id):
        villagers[villager_id]["job"] = "Unassigned"
        villagers[villager_id]["active"] = false
    job_states.erase(villager_id)
    if state:
        state.current_job = "IDLE"
        state.current_task = "IDLE"
        state.behavior_timer = 0.0
    settlement_changed.emit()
    return true

func process_villager_needs(states: Array[NPCState]) -> void:
    for state in states:
        if state == null or not state.alive or not villagers.has(state.npc_id):
            continue
        var record: Dictionary = villagers[state.npc_id]
        if state.hunger <= 65.0 and food_stock > 0:
            food_stock -= 1
            state.hunger = 100.0
            record["food"] = 1.0
        if state.thirst <= 65.0 and water_stock > 0:
            water_stock -= 1
            state.thirst = 100.0
            record["water"] = 1.0
        record["health"] = state.health / NPCState.MAX_STAT
        record["food"] = state.hunger / NPCState.MAX_STAT
        record["water"] = state.thirst / NPCState.MAX_STAT
        villagers[state.npc_id] = record
    settlement_changed.emit()

func get_settlement_state() -> Dictionary:
    var serialized_jobs := {}
    for villager_id in job_states.keys():
        var job: JobState = job_states[villager_id]
        if job != null and job.is_valid():
            serialized_jobs[str(villager_id)] = job.to_dict()
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
        "villagers": villagers.duplicate(true),
        "jobs": serialized_jobs,
        "productions": production_manager.serialize_states(),
        "next_job_index": _next_job_index
    }

func load_settlement_state(state: Dictionary) -> void:
    if state.is_empty():
        return
    settlement_name = str(state.get("name", settlement_name))
    water_cycle_index = maxi(0, int(state.get("water_cycle_index", 0)))
    last_water_shortage = maxi(0, int(state.get("water_shortage", 0)))
    _water_clock_initialized = false
    var stock: Dictionary = state.get("stock", {})
    food_stock = maxi(0, int(stock.get("food", 0)))
    water_stock = maxi(0, int(stock.get("water", 0)))
    wood_stock = maxi(0, int(stock.get("wood", 0)))
    stone_stock = maxi(0, int(stock.get("stone", 0)))
    buildings = state.get("buildings", {}).duplicate(true)
    villagers = state.get("villagers", {}).duplicate(true)
    population = villagers.size()
    _next_job_index = maxi(1, int(state.get("next_job_index", 1)))

    job_states.clear()
    var saved_jobs = state.get("jobs", {})
    if saved_jobs is Dictionary:
        for villager_id in saved_jobs.keys():
            var data = saved_jobs[villager_id]
            if data is Dictionary:
                var job := JobState.from_dict(data)
                if job.is_valid() and job.active:
                    job_states[str(villager_id)] = job

    production_manager.load_states(state.get("productions", {}) if state.get("productions", {}) is Dictionary else {})
    settlement_changed.emit()
