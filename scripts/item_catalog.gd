extends RefCounted
class_name VeyraItemCatalog

const ITEM_TYPES: Array[String] = [
	"I01_STONE_AXE",
	"I02_STONE_PICK",
	"I03_CAMPFIRE_KIT"
]

static func is_valid(item_id: String) -> bool:
	return item_id in ITEM_TYPES

static func display_name(item_id: String) -> String:
	match item_id:
		"I01_STONE_AXE":
			return "Stone Axe"
		"I02_STONE_PICK":
			return "Stone Pick"
		"I03_CAMPFIRE_KIT":
			return "Campfire Kit"
		_:
			return item_id

static func max_stack(item_id: String) -> int:
	return 1 if item_id != "I03_CAMPFIRE_KIT" else 5

static func weight(item_id: String) -> float:
	match item_id:
		"I01_STONE_AXE":
			return 2.5
		"I02_STONE_PICK":
			return 3.0
		"I03_CAMPFIRE_KIT":
			return 4.0
		_:
			return 1.0
