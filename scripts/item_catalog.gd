extends RefCounted
class_name VeyraItemCatalog

const ITEM_TYPES: Array[String] = [
	"I01_STONE_AXE",
	"I02_STONE_PICK",
	"I03_CAMPFIRE_KIT"
]

const TOOL_IDS: Array[String] = ["I01_STONE_AXE", "I02_STONE_PICK"]

static func is_valid(item_id: String) -> bool:
	return item_id in ITEM_TYPES

static func is_tool(item_id: String) -> bool:
	return item_id in TOOL_IDS

static func is_tool_for_resource(item_id: String, resource_type: String) -> bool:
	match resource_type:
		"Wood":
			return item_id == "I01_STONE_AXE"
		"Stone", "Metal":
			return item_id == "I02_STONE_PICK"
		_:
			return false

static func gathering_bonus(item_id: String, resource_type: String) -> int:
	return 1 if is_tool_for_resource(item_id, resource_type) else 0

static func durability_cost(item_id: String, resource_type: String) -> float:
	if not is_tool_for_resource(item_id, resource_type):
		return 0.0
	return 1.0

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
