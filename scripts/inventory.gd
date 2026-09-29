extends Node
class_name VeyraInventory

signal inventory_changed(snapshot: Dictionary, changed_type: String, changed_amount: int)

@export var max_slots: int = 24
@export var max_weight: float = 400.0 # Temporary alpha testing capacity for the 100 Wood + 100 Stone starter cache.

var resources: Dictionary = {}
var items: Dictionary = {}
var total_weight: float = 0.0
var coins: int = 0

func get_coins() -> int:
	return maxi(0, coins)

func add_coins(amount: int) -> int:
	if amount <= 0:
		return 0
	coins += amount
	inventory_changed.emit(get_snapshot(), "Coins", amount)
	return amount

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	inventory_changed.emit(get_snapshot(), "Coins", -amount)
	return true

func add_resource(resource_type: String, amount: int) -> int:
    if amount <= 0 or not VeyraResourceCatalog.is_valid(resource_type):
        return 0

    var current := get_amount(resource_type)
    var stack_limit := VeyraResourceCatalog.max_stack(resource_type)
    var free_stack_space := 0
    if current > 0:
        free_stack_space = stack_limit - (current % stack_limit)
        if free_stack_space == stack_limit:
            free_stack_space = 0
    var free_slots := maxi(0, max_slots - _used_slots())
    var capacity_by_slots := free_stack_space + free_slots * stack_limit
    var accepted := mini(amount, capacity_by_slots)

    var per_item_weight := VeyraResourceCatalog.weight(resource_type)
    if per_item_weight > 0.0:
        accepted = mini(accepted, int(floor(maxf(0.0, max_weight - total_weight) / per_item_weight)))

    if accepted <= 0:
        return 0

    resources[resource_type] = current + accepted
    total_weight += accepted * per_item_weight
    inventory_changed.emit(get_snapshot(), resource_type, accepted)
    return accepted

func remove_resource(resource_type: String, amount: int) -> int:
    if amount <= 0:
        return 0

    var current := get_amount(resource_type)
    var removed := mini(amount, current)
    if removed <= 0:
        return 0

    var remaining := current - removed
    if remaining > 0:
        resources[resource_type] = remaining
    else:
        resources.erase(resource_type)

    total_weight = maxf(0.0, total_weight - removed * VeyraResourceCatalog.weight(resource_type))
    inventory_changed.emit(get_snapshot(), resource_type, -removed)
    return removed

func has_resource(resource_type: String, amount: int = 1) -> bool:
    return amount > 0 and get_amount(resource_type) >= amount

func get_amount(resource_type: String) -> int:
    return maxi(0, int(resources.get(resource_type, 0)))

func get_free_slots() -> int:
    return maxi(0, max_slots - _used_slots())

func get_total_weight() -> float:
    return total_weight

func get_capacity_state() -> Dictionary:
    return {
        "slots_used": _used_slots(),
        "slots_max": maxi(0, max_slots),
        "weight": total_weight,
        "weight_max": maxf(0.0, max_weight)
    }

func get_snapshot() -> Dictionary:
    return {
        "resources": resources.duplicate(true),
        "items": items.duplicate(true),
        "coins": coins
    }

func load_snapshot(snapshot: Dictionary) -> void:
    resources.clear()
    items.clear()
    total_weight = 0.0

    if snapshot is Dictionary:
        coins = maxi(0, int(snapshot.get("coins", 0)))
        var resource_snapshot: Dictionary = snapshot.get("resources", snapshot)
        if resource_snapshot is Dictionary:
            for key in resource_snapshot.keys():
                if key is not String or not VeyraResourceCatalog.is_valid(key):
                    continue
                var value = resource_snapshot[key]
                if not (value is int or value is float):
                    continue
                var amount := maxi(0, int(value))
                if amount > 0:
                    _load_amount(str(key), amount)

        var item_snapshot: Dictionary = snapshot.get("items", {})
        if item_snapshot is Dictionary:
            for key in item_snapshot.keys():
                if key is not String or not VeyraItemCatalog.is_valid(key):
                    continue
                var value = item_snapshot[key]
                if value is int or value is float:
                    var amount := maxi(0, int(value))
                    if amount > 0:
                        add_item(str(key), amount)

    inventory_changed.emit(get_snapshot(), "", 0)

func _load_amount(resource_type: String, amount: int) -> int:
    var current := get_amount(resource_type)
    var stack_limit := VeyraResourceCatalog.max_stack(resource_type)
    var free_slots := maxi(0, max_slots - _used_slots())
    var free_stack_space := 0
    if current > 0:
        free_stack_space = stack_limit - (current % stack_limit)
        if free_stack_space == stack_limit:
            free_stack_space = 0
    var capacity_by_slots := free_stack_space + free_slots * stack_limit
    var accepted := mini(amount, capacity_by_slots)
    var weight := VeyraResourceCatalog.weight(resource_type)
    if weight > 0.0:
        accepted = mini(accepted, int(floor(maxf(0.0, max_weight - total_weight) / weight)))
    if accepted > 0:
        resources[resource_type] = current + accepted
        total_weight += accepted * weight
    return accepted

func add_item(item_id: String, amount: int) -> int:
    if amount <= 0 or not VeyraItemCatalog.is_valid(item_id):
        return 0

    var current := get_item_amount(item_id)
    var stack_limit := VeyraItemCatalog.max_stack(item_id)
    var free_slots := maxi(0, max_slots - _used_slots())
    var free_stack_space := 0
    if current > 0:
        free_stack_space = stack_limit - (current % stack_limit)
        if free_stack_space == stack_limit:
            free_stack_space = 0
    var capacity := free_stack_space + free_slots * stack_limit
    var accepted := mini(amount, capacity)
    var item_weight := VeyraItemCatalog.weight(item_id)
    if item_weight > 0.0:
        accepted = mini(accepted, int(floor(maxf(0.0, max_weight - total_weight) / item_weight)))
    if accepted <= 0:
        return 0

    items[item_id] = current + accepted
    total_weight += accepted * item_weight
    inventory_changed.emit(get_snapshot(), item_id, accepted)
    return accepted

func remove_item(item_id: String, amount: int) -> int:
    if amount <= 0:
        return 0
    var current := get_item_amount(item_id)
    var removed := mini(amount, current)
    if removed <= 0:
        return 0

    if current - removed > 0:
        items[item_id] = current - removed
    else:
        items.erase(item_id)
    total_weight = maxf(0.0, total_weight - removed * VeyraItemCatalog.weight(item_id))
    inventory_changed.emit(get_snapshot(), item_id, -removed)
    return removed

func has_item(item_id: String, amount: int = 1) -> bool:
    return amount > 0 and get_item_amount(item_id) >= amount

func get_item_amount(item_id: String) -> int:
    return maxi(0, int(items.get(item_id, 0)))

func get_items_snapshot() -> Dictionary:
    return items.duplicate(true)

func _used_slots() -> int:
    var slots := 0
    for key in resources.keys():
        var amount := int(resources[key])
        if amount > 0:
            slots += int(ceili(float(amount) / float(VeyraResourceCatalog.max_stack(str(key)))))
    for key in items.keys():
        var amount := int(items[key])
        if amount > 0:
            slots += int(ceili(float(amount) / float(VeyraItemCatalog.max_stack(str(key)))))
    return slots


func clear() -> void:
    resources.clear()
    items.clear()
    total_weight = 0.0
    coins = 0
    inventory_changed.emit(get_snapshot(), "", 0)

func get_resource_types() -> Array[String]:
    var result: Array[String] = []
    for resource_type in resources.keys():
        if int(resources[resource_type]) > 0:
            result.append(str(resource_type))
    result.sort()
    return result

func get_item_types() -> Array[String]:
    var result: Array[String] = []
    for item_id in items.keys():
        if int(items[item_id]) > 0:
            result.append(str(item_id))
    result.sort()
    return result
