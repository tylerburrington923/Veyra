extends Node
class_name VeyraInventory

signal inventory_changed(snapshot: Dictionary, changed_type: String, changed_amount: int)

@export var max_slots: int = 24
@export var max_weight: float = 120.0

var resources: Dictionary = {}
var total_weight: float = 0.0

func add_resource(resource_type: String, amount: int) -> int:
    if amount <= 0 or not VeyraResourceCatalog.is_valid(resource_type):
        return 0

    var current := get_amount(resource_type)
    var stack_limit := VeyraResourceCatalog.max_stack(resource_type)
    var free_slots := maxi(0, max_slots - _used_slots())
    var capacity_by_slots := free_slots * stack_limit
    if current > 0 and current % stack_limit != 0:
        capacity_by_slots += stack_limit - (current % stack_limit)
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
    return resources.duplicate(true)

func load_snapshot(snapshot: Dictionary) -> void:
    resources.clear()
    total_weight = 0.0

    if snapshot is Dictionary:
        for key in snapshot.keys():
            if key is not String or not VeyraResourceCatalog.is_valid(key):
                continue
            var value = snapshot[key]
            if not (value is int or value is float):
                continue
            var amount := maxi(0, int(value))
            if amount > 0:
                _load_amount(str(key), amount)

    inventory_changed.emit(get_snapshot(), "", 0)

func _load_amount(resource_type: String, amount: int) -> int:
    var current := get_amount(resource_type)
    var stack_limit := VeyraResourceCatalog.max_stack(resource_type)
    var free_slots := maxi(0, max_slots - _used_slots())
    var capacity_by_slots := free_slots * stack_limit
    if current > 0:
        capacity_by_slots += stack_limit - (current % stack_limit)
    var accepted := mini(amount, capacity_by_slots)
    var weight := VeyraResourceCatalog.weight(resource_type)
    if weight > 0.0:
        accepted = mini(accepted, int(floor(maxf(0.0, max_weight - total_weight) / weight)))
    if accepted > 0:
        resources[resource_type] = current + accepted
        total_weight += accepted * weight
    return accepted

func _used_slots() -> int:
    var slots := 0
    for key in resources.keys():
        var amount := int(resources[key])
        if amount > 0:
            slots += int(ceili(float(amount) / float(VeyraResourceCatalog.max_stack(str(key)))))
    return slots
