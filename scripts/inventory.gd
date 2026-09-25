extends Node
class_name VeyraInventory

signal inventory_changed(snapshot: Dictionary, changed_type: String, changed_amount: int)

var resources: Dictionary = {}

func add_resource(resource_type: String, amount: int) -> void:
    if amount <= 0:
        return
    var new_amount: int = maxi(0, int(resources.get(resource_type, 0)) + amount)
    resources[resource_type] = new_amount
    inventory_changed.emit(get_snapshot(), resource_type, amount)

func get_amount(resource_type: String) -> int:
    return maxi(0, int(resources.get(resource_type, 0)))

func get_snapshot() -> Dictionary:
    return resources.duplicate(true)

func load_snapshot(snapshot: Dictionary) -> void:
    resources.clear()
    for key in snapshot.keys():
        var value = snapshot[key]
        if key is String and (value is int or value is float) and int(value) > 0:
            resources[key] = int(value)
    inventory_changed.emit(get_snapshot(), "", 0)
