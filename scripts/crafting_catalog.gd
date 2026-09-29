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
	"I04_METAL_AXE": {
		"id": "I04_METAL_AXE",
		"name": "Metal Axe",
		"cost": {"Refined Metal": 2, "Wood": 2},
		"output": 1
	},
	"I05_METAL_PICK": {
		"id": "I05_METAL_PICK",
		"name": "Metal Pick",
		"cost": {"Refined Metal": 2, "Wood": 2},
		"output": 1
	},
	"I06_ECHO_AXE": {
		"id": "I06_ECHO_AXE",
		"name": "Echo Axe",
		"cost": {"Refined Metal": 2, "Echo-Stone": 1, "Vitreous Lux": 1, "Wood": 2},
		"output": 1
	},
	"I07_ECHO_PICK": {
		"id": "I07_ECHO_PICK",
		"name": "Echo Pick",
		"cost": {"Refined Metal": 2, "Echo-Stone": 1, "Vitreous Lux": 1, "Wood": 2},
		"output": 1
	},
	"I08_HUNTER_KNIFE": {
		"id": "I08_HUNTER_KNIFE",
		"name": "Hunter Knife",
		"cost": {"Stone": 2, "Wood": 1, "Hide": 1},
		"output": 1
	},
	"I09_STONE_SPEAR": {
		"id": "I09_STONE_SPEAR",
		"name": "Stone Spear",
		"cost": {"Stone": 2, "Wood": 3},
		"output": 1
	},
	"I10_METAL_SPEAR": {
		"id": "I10_METAL_SPEAR",
		"name": "Metal Spear",
		"cost": {"Refined Metal": 2, "Wood": 3, "Leather": 1},
		"output": 1
	},
	"A01_HIDE_CAP": {
		"id": "A01_HIDE_CAP",
		"name": "Hide Cap",
		"cost": {"Hide": 3},
		"output": 1
	},
	"A02_HIDE_VEST": {
		"id": "A02_HIDE_VEST",
		"name": "Hide Vest",
		"cost": {"Hide": 6},
		"output": 1
	},
	"A03_LEATHER_ARMOR": {
		"id": "A03_LEATHER_ARMOR",
		"name": "Leather Armor",
		"cost": {"Leather": 8, "Hide": 2},
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
