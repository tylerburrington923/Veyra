extends Node
class_name VeyraInventory

var resources: Dictionary = {}

func add_resource(resource_type: String, amount: int) -> void:
    if amount <= 0:
        return
    resources[resource_type] = maxi(0, int(resources.get(resource_type, 0)) + amount)

func get_amount(resource_type: String) -> int:
    return maxi(0, int(resources.get(resource_type, 0)))

func get_snapshot() -> Dictionary:
    return resources.duplicate(true)

func load_snapshot(snapshot: Dictionary) -> void:
    resources.clear()
    for key in snapshot.keys():
        var value = snapshot[key]
        if key is String and value is int and value > 0:
            resources[key] = value
