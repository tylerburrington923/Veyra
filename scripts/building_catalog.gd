extends RefCounted
class_name VeyraBuildingCatalog

const BUILDINGS := {
	"B01_CAMPFIRE": {
		"id": "B01_CAMPFIRE",
		"name": "Campfire",
		"size": Vector2(2.4, 2.4),
		"cost": {"Stone": 4, "Wood": 4}
	},
	"B02_STORAGE": {
		"id": "B02_STORAGE",
		"name": "Storage Crate",
		"size": Vector2(2.2, 2.0),
		"cost": {"Wood": 12, "Stone": 4}
	},
	"B03_SHELTER": {
		"id": "B03_SHELTER",
		"name": "House",
		"size": Vector2(5.8, 4.8),
		"cost": {"Wood": 40, "Stone": 10}
	},
	"B04_WELL": {
		"id": "B04_WELL",
		"name": "Well",
		"size": Vector2(3.0, 3.0),
		"cost": {"Stone": 20, "Wood": 10}
	},
	"B05_TOWNHALL": {
		"id": "B05_TOWNHALL",
		"name": "Town Hall",
		"size": Vector2(8.0, 7.0),
		"cost": {"Wood": 60, "Stone": 40}
	},
	"B06_SHRINE": {
		"id": "B06_SHRINE",
		"name": "Resonance Shrine",
		"size": Vector2(3.0, 3.0),
		"cost": {"Stone": 18, "Vitreous Lux": 4}
	},
	"B07_WATCHTOWER": {
		"id": "B07_WATCHTOWER",
		"name": "Watchtower",
		"size": Vector2(3.0, 3.0),
		"cost": {"Wood": 28, "Stone": 12}
	},
	"B10_TANNERY": {
		"id": "B10_TANNERY",
		"name": "Tannery",
		"size": Vector2(4.0, 3.5),
		"cost": {"Wood": 24, "Stone": 12, "Hide": 6}
	},
	"B09_BLACKSMITH": {
		"id": "B09_BLACKSMITH",
		"name": "Blacksmith",
		"size": Vector2(4.5, 4.0),
		"cost": {"Wood": 30, "Stone": 30, "Metal": 10}
	},
	"B08_GARDEN": {
		"id": "B08_GARDEN",
		"name": "Lunar Garden",
		"size": Vector2(4.0, 4.0),
		"cost": {"Wood": 10, "Stone": 6, "Vitreous Lux": 2}
	}
}

static func exists(building_id: String) -> bool:
	return BUILDINGS.has(building_id)

static func get_building(building_id: String) -> Dictionary:
	return BUILDINGS.get(building_id, {}).duplicate(true)

static func all_building_ids() -> Array[String]:
	var result: Array[String] = []
	for key in BUILDINGS.keys():
		result.append(str(key))
	result.sort()
	return result
