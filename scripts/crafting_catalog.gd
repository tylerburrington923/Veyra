extends RefCounted
class_name VeyraCraftingCatalog

const RECIPES := {
	"I01_STONE_AXE": {
		"id": "I01_STONE_AXE",
		"name": "Stone Axe",
		"cost": {"Stone": 2, "Wood": 3},
		"output": 1
	},
	"I02_STONE_PICK": {
		"id": "I02_STONE_PICK",
		"name": "Stone Pick",
		"cost": {"Stone": 3, "Wood": 2},
		"output": 1
	},
	"I03_CAMPFIRE_KIT": {
		"id": "I03_CAMPFIRE_KIT",
		"name": "Campfire Kit",
		"cost": {"Stone": 4, "Wood": 4},
		"output": 1
	}
}

static func exists(recipe_id: String) -> bool:
	return RECIPES.has(recipe_id)

static func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {}).duplicate(true)

static func all_recipe_ids() -> Array[String]:
	var result: Array[String] = []
	for key in RECIPES.keys():
		result.append(str(key))
	result.sort()
	return result
