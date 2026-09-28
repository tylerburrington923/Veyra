extends Node
class_name VeyraCraftingManager

signal crafting_completed(recipe_id: String, output_item: String, amount: int)
signal crafting_failed(recipe_id: String, reason: String)

func _ready() -> void:
	add_to_group("crafting_manager")

func can_craft(recipe_id: String, inventory: VeyraInventory) -> bool:
	if not inventory or not VeyraCraftingCatalog.exists(recipe_id):
		return false
	var recipe := VeyraCraftingCatalog.get_recipe(recipe_id)
	var cost: Dictionary = recipe.get("cost", {})
	for resource_type in cost.keys():
		if not inventory.has_resource(str(resource_type), int(cost[resource_type])):
			return false
	return inventory.get_free_slots() > 0 or inventory.get_item_amount(str(recipe.get("id", ""))) > 0

func craft(recipe_id: String, inventory: VeyraInventory) -> bool:
	if not can_craft(recipe_id, inventory):
		crafting_failed.emit(recipe_id, "requirements")
		return false

	var recipe := VeyraCraftingCatalog.get_recipe(recipe_id)
	var cost: Dictionary = recipe.get("cost", {})
	for resource_type in cost.keys():
		inventory.remove_resource(str(resource_type), int(cost[resource_type]))

	var item_id := str(recipe.get("output_item", recipe.get("id", "")))
	var output := maxi(1, int(recipe.get("output", 1)))
	var accepted := inventory.add_item(item_id, output)
	if accepted < output:
		for resource_type in cost.keys():
			inventory.add_resource(str(resource_type), int(cost[resource_type]))
		crafting_failed.emit(recipe_id, "inventory_full")
		return false

	var progression := get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("record_action"):
		progression.record_action("CRAFT", accepted, item_id)
	crafting_completed.emit(recipe_id, item_id, accepted)
	return true
