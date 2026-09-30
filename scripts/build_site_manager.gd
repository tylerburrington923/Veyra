extends Node
class_name VeyraBuildSiteManager

## Settlement construction logistics.
## Foundations are free. Materials are delivered separately by the player or
## dispatched from the Town Hall through a worker delivery order.

signal build_site_changed(site_id: String)
signal build_site_completed(site_id: String, building_id: String)
signal delivery_queued(order_id: String, site_id: String, worker_id: String)
signal delivery_completed(order_id: String, site_id: String)

const SAVE_VERSION := 1
const DELIVERY_TRAVEL_SECONDS := 1.25
const MAX_PLAYER_DEPOSIT_DISTANCE := 6.0

var build_sites: Dictionary = {}
var delivery_orders: Dictionary = {}
var _next_site_index: int = 1
var _next_order_index: int = 1

func _ready() -> void:
	add_to_group("build_site_manager")
	set_process(true)
	call_deferred("_restore_presentations")

func _process(delta: float) -> void:
	if not _is_authoritative():
		return
	if delta <= 0.0 or delivery_orders.is_empty():
		return
	var completed_orders: Array[String] = []
	for order_id in delivery_orders.keys():
		var order: Dictionary = delivery_orders[order_id]
		if not _worker_has_reached_site(order):
			continue
		order["remaining_time"] = maxf(0.0, float(order.get("remaining_time", DELIVERY_TRAVEL_SECONDS)) - delta)
		delivery_orders[order_id] = order
		if float(order["remaining_time"]) <= 0.0:
			completed_orders.append(str(order_id))
	for order_id in completed_orders:
		_complete_delivery(order_id)

func create_foundation(building_id: String, building_type: String, position: Vector3, cost: Dictionary, creator_peer_id: int = 1) -> String:
	if not _is_authoritative():
		return ""
	if not VeyraBuildingCatalog.exists(building_type) or cost.is_empty():
		return ""
	if building_type == "B05_TOWNHALL" and _townhall_exists_or_reserved():
		return ""
	if _has_site_near(position, VeyraBuildingCatalog.get_building(building_type).get("size", Vector2.ONE)):
		return ""
	var site_id := "SITE-%04d" % _next_site_index
	_next_site_index += 1
	var normalized_cost := _sanitize_resource_map(cost)
	build_sites[site_id] = {
		"id": site_id,
		"building_id": building_id,
		"building_type": building_type,
		"position": [position.x, position.y, position.z],
		"cost": normalized_cost,
		"delivered": {},
		"creator_peer_id": maxi(1, creator_peer_id),
		"created_at": Time.get_unix_time_from_system()
	}
	_spawn_site_visual(site_id)
	build_site_changed.emit(site_id)
	return site_id

func has_site(site_id: String) -> bool:
	return build_sites.has(site_id)

func get_site(site_id: String) -> Dictionary:
	var site = build_sites.get(site_id, {})
	return site.duplicate(true) if site is Dictionary else {}

func get_all_sites() -> Dictionary:
	return build_sites.duplicate(true)

func get_remaining_materials(site_id: String) -> Dictionary:
	var site := get_site(site_id)
	if site.is_empty():
		return {}
	var result: Dictionary = {}
	var cost: Dictionary = site.get("cost", {})
	var delivered: Dictionary = site.get("delivered", {})
	for resource_type in cost.keys():
		var remaining := maxi(0, int(cost[resource_type]) - int(delivered.get(resource_type, 0)))
		if remaining > 0:
			result[str(resource_type)] = remaining
	return result

func get_completion_ratio(site_id: String) -> float:
	var site := get_site(site_id)
	if site.is_empty():
		return 0.0
	var cost: Dictionary = site.get("cost", {})
	var delivered: Dictionary = site.get("delivered", {})
	var total := 0
	var supplied := 0
	for resource_type in cost.keys():
		var required := maxi(0, int(cost[resource_type]))
		total += required
		supplied += mini(required, maxi(0, int(delivered.get(resource_type, 0))))
	return 1.0 if total <= 0 else float(supplied) / float(total)

func deposit_from_player(site_id: String, player: Node, requested: Dictionary = {}) -> bool:
	if not _is_authoritative():
		return false
	var site := get_site(site_id)
	if site.is_empty() or not player or not player.has_method("get_inventory"):
		return false
	if player is Node3D:
		var site_position := _site_position(site)
		if (player as Node3D).global_position.distance_to(site_position) > MAX_PLAYER_DEPOSIT_DISTANCE:
			return false
	var inventory: VeyraInventory = player.get_inventory()
	if not inventory:
		return false

	var remaining := get_remaining_materials(site_id)
	if remaining.is_empty():
		_complete_site(site_id)
		return true

	var delivered: Dictionary = site.get("delivered", {}).duplicate(true)
	var deposited := false
	for resource_type in remaining.keys():
		var wanted := int(remaining[resource_type])
		if requested.has(resource_type):
			wanted = mini(wanted, maxi(0, int(requested[resource_type])))
		if wanted <= 0:
			continue
		var removed := inventory.remove_resource(str(resource_type), wanted)
		if removed > 0:
			delivered[str(resource_type)] = int(delivered.get(resource_type, 0)) + removed
			deposited = true
	site["delivered"] = delivered
	build_sites[site_id] = site
	if deposited:
		build_site_changed.emit(site_id)
	if get_remaining_materials(site_id).is_empty():
		_complete_site(site_id)
	return deposited

func queue_worker_delivery(site_id: String, worker_id: String, requested: Dictionary) -> String:
	if not _is_authoritative():
		return ""
	var site := get_site(site_id)
	if site.is_empty() or worker_id.is_empty():
		return ""
	var townhall_id := _find_townhall_id()
	if townhall_id.is_empty():
		return ""
	var townhall_storage := _get_building_storage(townhall_id)
	var storage_resources: Dictionary = townhall_storage.get("resources", {}).duplicate(true)
	var remaining := get_remaining_materials(site_id)
	var cargo: Dictionary = {}
	for resource_type in requested.keys():
		var key := str(resource_type)
		var amount := mini(
			mini(maxi(0, int(requested[resource_type])), maxi(0, int(remaining.get(key, 0)))),
			maxi(0, int(storage_resources.get(key, 0)))
		)
		if amount > 0:
			cargo[key] = amount
			storage_resources[key] = int(storage_resources.get(key, 0)) - amount
	if cargo.is_empty():
		return ""
	townhall_storage["resources"] = storage_resources
	if not _set_building_storage(townhall_id, townhall_storage):
		return ""
	var order_id := "DEL-%04d" % _next_order_index
	_next_order_index += 1
	delivery_orders[order_id] = {
		"id": order_id,
		"site_id": site_id,
		"worker_id": worker_id,
		"cargo": cargo,
		"remaining_time": DELIVERY_TRAVEL_SECONDS,
		"source_building_id": townhall_id
	}
	_set_worker_delivery_state(worker_id, site_id)
	delivery_queued.emit(order_id, site_id, worker_id)
	return order_id

func dispatch_available_worker(site_id: String, requested: Dictionary) -> String:
	var worker_id := _find_available_worker()
	if worker_id.is_empty():
		return ""
	return queue_worker_delivery(site_id, worker_id, requested)

func cancel_delivery(order_id: String) -> bool:
	if not _is_authoritative() or not delivery_orders.has(order_id):
		return false
	var order: Dictionary = delivery_orders[order_id]
	_return_cargo_to_townhall(order)
	delivery_orders.erase(order_id)
	_clear_worker_delivery_state(str(order.get("worker_id", "")))
	return true

func _return_cargo_to_townhall(order: Dictionary) -> void:
	var townhall_id := str(order.get("source_building_id", ""))
	if townhall_id.is_empty():
		return
	var storage := _get_building_storage(townhall_id)
	var resources: Dictionary = storage.get("resources", {}).duplicate(true)
	for resource_type in order.get("cargo", {}).keys():
		var key := str(resource_type)
		resources[key] = int(resources.get(key, 0)) + maxi(0, int(order["cargo"][resource_type]))
	storage["resources"] = resources
	_set_building_storage(townhall_id, storage)

func get_pending_delivery_for_site(site_id: String) -> Array:
	var result: Array = []
	for order in delivery_orders.values():
		if str(order.get("site_id", "")) == site_id:
			result.append(order.duplicate(true))
	return result

func get_save_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"next_site_index": _next_site_index,
		"next_order_index": _next_order_index,
		"build_sites": build_sites.duplicate(true),
		"delivery_orders": delivery_orders.duplicate(true)
	}

func load_save_state(state: Dictionary) -> void:
	build_sites.clear()
	delivery_orders.clear()
	_next_site_index = maxi(1, int(state.get("next_site_index", 1)))
	_next_order_index = maxi(1, int(state.get("next_order_index", 1)))
	var saved_sites = state.get("build_sites", {})
	if saved_sites is Dictionary:
		for site_id in saved_sites.keys():
			var clean := _sanitize_site(saved_sites[site_id])
			if not clean.is_empty():
				build_sites[str(site_id)] = clean
	var saved_orders = state.get("delivery_orders", {})
	if saved_orders is Dictionary:
		for order_id in saved_orders.keys():
			var clean_order := _sanitize_order(saved_orders[order_id])
			if not clean_order.is_empty():
				delivery_orders[str(order_id)] = clean_order
	for order in delivery_orders.values():
		_set_worker_delivery_state(str(order.get("worker_id", "")), str(order.get("site_id", "")))
	call_deferred("_restore_presentations")
	for order in delivery_orders.values():
		_set_worker_delivery_state(str(order.get("worker_id", "")), str(order.get("site_id", "")))

func remove_site(site_id: String) -> bool:
	if not build_sites.has(site_id):
		return false
	var visual := get_tree().current_scene.get_node_or_null("BuildSites/" + site_id)
	if visual:
		visual.queue_free()
	build_sites.erase(site_id)
	for order_id in delivery_orders.keys().duplicate():
		if str(delivery_orders[order_id].get("site_id", "")) == site_id:
			cancel_delivery(str(order_id))
	build_site_changed.emit(site_id)
	return true

func _complete_delivery(order_id: String) -> void:
	if not delivery_orders.has(order_id):
		return
	var order: Dictionary = delivery_orders[order_id]
	var site_id := str(order.get("site_id", ""))
	if not build_sites.has(site_id):
		_return_cargo_to_townhall(order)
		delivery_orders.erase(order_id)
		_clear_worker_delivery_state(str(order.get("worker_id", "")))
		return
	var site: Dictionary = build_sites[site_id]
	var delivered: Dictionary = site.get("delivered", {}).duplicate(true)
	var remaining := get_remaining_materials(site_id)
	var excess_cargo: Dictionary = {}
	for resource_type in order.get("cargo", {}).keys():
		var key := str(resource_type)
		var cargo_amount := maxi(0, int(order["cargo"][resource_type]))
		var accepted := mini(cargo_amount, maxi(0, int(remaining.get(key, 0))))
		if accepted > 0:
			delivered[key] = int(delivered.get(key, 0)) + accepted
		if cargo_amount > accepted:
			excess_cargo[key] = cargo_amount - accepted
	site["delivered"] = delivered
	build_sites[site_id] = site
	delivery_orders.erase(order_id)
	if not excess_cargo.is_empty():
		var return_order := order.duplicate(true)
		return_order["cargo"] = excess_cargo
		_return_cargo_to_townhall(return_order)
	delivery_completed.emit(order_id, site_id)
	build_site_changed.emit(site_id)
	_clear_worker_delivery_state(str(order.get("worker_id", "")))
	if get_remaining_materials(site_id).is_empty():
		_complete_site(site_id)

func _complete_site(site_id: String) -> void:
	if not build_sites.has(site_id):
		return
	var site: Dictionary = build_sites[site_id]
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement or not settlement.has_method("add_building"):
		return
	var building_id := str(site.get("building_id", ""))
	var building_type := str(site.get("building_type", ""))
	var position := _site_position(site)
	if not bool(settlement.call("add_building", building_id, building_type, position)):
		return
	for order_id in delivery_orders.keys().duplicate():
		if str(delivery_orders[order_id].get("site_id", "")) == site_id:
			cancel_delivery(str(order_id))
	var visual := get_tree().current_scene.get_node_or_null("BuildSites/" + site_id)
	if visual:
		visual.queue_free()
	build_sites.erase(site_id)
	var building_manager := get_node_or_null("/root/BuildingManager")
	if building_manager and building_manager.has_method("_spawn_building_visual"):
		building_manager.call("_spawn_building_visual", building_id, building_type, position)
	var typed_building_manager := building_manager as VeyraBuildingManager
	if typed_building_manager:
		typed_building_manager.building_completed.emit(building_id, position)
	build_site_completed.emit(site_id, building_type)

func _spawn_site_visual(site_id: String) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var root := scene.get_node_or_null("BuildSites") as Node3D
	if not root:
		root = Node3D.new()
		root.name = "BuildSites"
		scene.add_child(root)
	if root.get_node_or_null(site_id):
		return
	var site := VeyraBuildSiteInstance.new()
	site.name = site_id
	root.add_child(site)
	site.setup(site_id, self)
	site.global_position = _site_position(get_site(site_id))

func restore_presentations() -> void:
	_restore_presentations()

func _restore_presentations() -> void:
	for site_id in build_sites.keys():
		_spawn_site_visual(str(site_id))

func _has_site_near(position: Vector3, size: Vector2) -> bool:
	for site in build_sites.values():
		if not site is Dictionary:
			continue
		var other := _site_position(site)
		var other_size := Vector2.ONE
		var definition := VeyraBuildingCatalog.get_building(str(site.get("building_type", "")))
		if not definition.is_empty():
			other_size = definition.get("size", Vector2.ONE)
		var radius := maxf(size.length(), other_size.length()) * 0.45
		if other.distance_to(position) < radius:
			return true
	return false

func _site_position(site: Dictionary) -> Vector3:
	var raw = site.get("position", [0.0, 0.0, 0.0])
	if raw is Array and raw.size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO

func _find_townhall_id() -> String:
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement:
		return ""
	for building_id in settlement.buildings.keys():
		var record = settlement.buildings[building_id]
		if record is Dictionary and str(record.get("type", "")) == "B05_TOWNHALL":
			return str(building_id)
	return ""

func _get_building_storage(building_id: String) -> Dictionary:
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement or not settlement.has_method("get_building_storage"):
		return {}
	return settlement.get_building_storage(building_id)

func _set_building_storage(building_id: String, storage: Dictionary) -> bool:
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement or not settlement.has_method("set_building_storage"):
		return false
	return bool(settlement.set_building_storage(building_id, storage))

func _find_available_worker() -> String:
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement:
		return ""
	var busy_workers: Dictionary = {}
	for order in delivery_orders.values():
		busy_workers[str(order.get("worker_id", ""))] = true
	for worker_id in settlement.villagers.keys():
		var record = settlement.villagers[worker_id]
		if busy_workers.has(str(worker_id)) or not record is Dictionary:
			continue
		var job := str(record.get("job", "")).to_upper()
		if job in ["BUILDER", "BUILD", "WORKER"] and not bool(record.get("active", false)):
			return str(worker_id)
	for worker_id in settlement.villagers.keys():
		var record = settlement.villagers[worker_id]
		if not busy_workers.has(str(worker_id)) and (not record is Dictionary or not bool(record.get("active", false))):
			return str(worker_id)
	return ""

func _worker_has_reached_site(order: Dictionary) -> bool:
	var npc_manager := get_tree().get_first_node_in_group("npc_manager")
	if not npc_manager or not npc_manager.has_method("is_worker_at_site"):
		return true
	return bool(npc_manager.is_worker_at_site(str(order.get("worker_id", "")), str(order.get("site_id", ""))))

func _set_worker_delivery_state(worker_id: String, site_id: String) -> void:
	var npc_manager := get_tree().get_first_node_in_group("npc_manager")
	if npc_manager and npc_manager.has_method("set_delivery_target"):
		npc_manager.set_delivery_target(worker_id, site_id)

func _clear_worker_delivery_state(worker_id: String) -> void:
	var npc_manager := get_tree().get_first_node_in_group("npc_manager")
	if npc_manager and npc_manager.has_method("clear_delivery_target"):
		npc_manager.clear_delivery_target(worker_id)

func _sanitize_resource_map(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in value.keys():
		var resource_type := str(key)
		var amount := maxi(0, int(value[key]))
		if amount > 0 and VeyraResourceCatalog.is_valid(resource_type):
			result[resource_type] = amount
	return result

func _sanitize_site(value) -> Dictionary:
	if not value is Dictionary:
		return {}
	var type_id := str(value.get("building_type", ""))
	if not VeyraBuildingCatalog.exists(type_id):
		return {}
	var position = value.get("position", [0.0, 0.0, 0.0])
	if not position is Array or position.size() < 3:
		position = [0.0, 0.0, 0.0]
	return {
		"id": str(value.get("id", "")),
		"building_id": str(value.get("building_id", "")),
		"building_type": type_id,
		"position": [float(position[0]), float(position[1]), float(position[2])],
		"cost": _sanitize_resource_map(value.get("cost", {})),
		"delivered": _sanitize_resource_map(value.get("delivered", {})),
		"creator_peer_id": maxi(1, int(value.get("creator_peer_id", 1))),
		"created_at": float(value.get("created_at", 0.0))
	}

func _sanitize_order(value) -> Dictionary:
	if not value is Dictionary:
		return {}
	var cargo := _sanitize_resource_map(value.get("cargo", {}))
	if cargo.is_empty():
		return {}
	return {
		"id": str(value.get("id", "")),
		"site_id": str(value.get("site_id", "")),
		"worker_id": str(value.get("worker_id", "")),
		"cargo": cargo,
		"remaining_time": clampf(float(value.get("remaining_time", DELIVERY_TRAVEL_SECONDS)), 0.0, DELIVERY_TRAVEL_SECONDS),
		"source_building_id": str(value.get("source_building_id", ""))
	}


func _is_authoritative() -> bool:
	var network := get_node_or_null("/root/NetworkManager")
	return network == null or not bool(network.get("session_active")) or bool(network.get("is_host"))


func _townhall_exists_or_reserved() -> bool:
	var settlement := get_node_or_null("/root/SettlementManager")
	if settlement and settlement.has_method("get_building"):
		var buildings: Dictionary = settlement.get("buildings")
		for record in buildings.values():
			if record is Dictionary and str(record.get("type", "")) == "B05_TOWNHALL":
				return true
	for site in build_sites.values():
		if site is Dictionary and str(site.get("building_type", "")) == "B05_TOWNHALL":
			return true
	return false
