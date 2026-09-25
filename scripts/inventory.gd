extends Node
class_name VeyraInventory

var resources: Dictionary = {}

func add_resource(resource_type: String, amount: int) -> void:
    resources[resource_type] = int(resources.get(resource_type, 0)) + amount
    print("Inventory: ", resource_type, " = ", resources[resource_type])

func get_amount(resource_type: String) -> int:
    return int(resources.get(resource_type, 0))

func get_snapshot() -> Dictionary:
    return resources.duplicate(true)
