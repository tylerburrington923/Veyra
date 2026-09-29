extends RefCounted
class_name VeyraItemCatalog

const ITEM_TYPES: Array[String] = [
	"I01_STONE_AXE",
	"I02_STONE_PICK",
	"I03_CAMPFIRE_KIT",
	"I04_METAL_AXE", "I05_METAL_PICK", "I06_ECHO_AXE", "I07_ECHO_PICK", "I08_HUNTER_KNIFE", "I09_STONE_SPEAR", "I10_METAL_SPEAR", "A01_HIDE_CAP", "A02_HIDE_VEST", "A03_LEATHER_ARMOR"
]

const TOOL_IDS: Array[String] = ["I01_STONE_AXE", "I02_STONE_PICK", "I04_METAL_AXE", "I05_METAL_PICK", "I06_ECHO_AXE", "I07_ECHO_PICK", "I08_HUNTER_KNIFE", "I09_STONE_SPEAR", "I10_METAL_SPEAR"]
const ARMOR_IDS: Array[String] = ["A01_HIDE_CAP", "A02_HIDE_VEST", "A03_LEATHER_ARMOR"]
const HANDS_ID := "T00_HANDS"

static func is_valid(item_id: String) -> bool:
	return item_id in ITEM_TYPES

static func is_valid_tool(tool_id: String) -> bool:
	return tool_id == HANDS_ID or tool_id in TOOL_IDS

static func is_tool_for_resource(item_id: String, resource_type: String) -> bool:
	match resource_type:
		"Wood":
			return item_id in ["I01_STONE_AXE", "I04_METAL_AXE", "I06_ECHO_AXE"]
		"Stone", "Metal", "Vitreous Lux", "Echo-Stone":
			return item_id in ["I02_STONE_PICK", "I05_METAL_PICK", "I07_ECHO_PICK"]
		_:
			return false

static func gathering_bonus(item_id: String, resource_type: String) -> int:
	if not is_tool_for_resource(item_id, resource_type):
		return 0
	if item_id in ["I06_ECHO_AXE", "I07_ECHO_PICK"]:
		return 3
	if item_id in ["I04_METAL_AXE", "I05_METAL_PICK"]:
		return 2
	return 1

static func durability_cost(item_id: String, resource_type: String) -> float:
	if not is_tool_for_resource(item_id, resource_type):
		return 0.0
	if item_id in ["I06_ECHO_AXE", "I07_ECHO_PICK"]:
		return 0.5
	if item_id in ["I04_METAL_AXE", "I05_METAL_PICK"]:
		return 0.75
	return 1.0

static func display_name(item_id: String) -> String:
	match item_id:
		"I01_STONE_AXE":
			return "Stone Axe"
		"I02_STONE_PICK":
			return "Stone Pick"
		"I03_CAMPFIRE_KIT":
			return "Campfire Kit"
		"I04_METAL_AXE":
			return "Metal Axe"
		"I05_METAL_PICK":
			return "Metal Pick"
		"I06_ECHO_AXE":
			return "Echo Axe"
		"I07_ECHO_PICK":
			return "Echo Pick"
		"I08_HUNTER_KNIFE":
			return "Hunter Knife"
		"I09_STONE_SPEAR":
			return "Stone Spear"
		"I10_METAL_SPEAR":
			return "Metal Spear"
		"A01_HIDE_CAP":
			return "Hide Cap"
		"A02_HIDE_VEST":
			return "Hide Vest"
		"A03_LEATHER_ARMOR":
			return "Leather Armor"
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
		"I04_METAL_AXE", "I05_METAL_PICK":
			return 3.0
		"I06_ECHO_AXE", "I07_ECHO_PICK":
			return 3.2
		"I08_HUNTER_KNIFE":
			return 1.0
		"I09_STONE_SPEAR":
			return 1.6
		"I10_METAL_SPEAR":
			return 1.8
		"A01_HIDE_CAP":
			return 0.8
		"A02_HIDE_VEST":
			return 2.0
		"A03_LEATHER_ARMOR":
			return 3.0
		_:
			return 1.0
