extends StaticBody3D

@export_enum("Stone", "Wood", "Metal", "Echo-Stone", "Vitreous Lux") var resource_type := "Stone"
## Presentation/collection variant. Inventory compatibility remains Wood/Stone.
@export_enum("stick", "small_stone", "large_stone", "tree", "metal", "lux") var node_kind := "large_stone"
@export var amount := 3
@export var tool_required := "I02_STONE_PICK"
@export var tool_efficiency := 1.0
@export var durability_cost := 1.0
@export var respawn_seconds := 45.0
@export var physical_collision := false

var resource_id: String = ""
var remaining: int = 0
var depleted := false
var respawn_time := 0.0
var interaction_cooldown := 0.0
var _visual_controller: Callable

func _ready() -> void:
	add_to_group("resource_node")
	collision_layer = 6 if physical_collision else 4
	collision_mask = 1
	remaining = maxi(0, amount)
	set_process(false)

func set_visual_controller(controller: Callable) -> void:
	_visual_controller = controller

func can_interact(player: Node) -> bool:
	if depleted or remaining <= 0 or interaction_cooldown > 0.0:
		return false
	if not player:
		return false
	var inventory: Node = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return false
	var equipped_tool := VeyraItemCatalog.HANDS_ID
	if player.has_method("get_tool_id"):
		equipped_tool = str(player.get_tool_id())
	if not VeyraItemCatalog.is_valid_tool(equipped_tool):
		return false
	if not VeyraItemCatalog.is_valid_tool(tool_required):
		return false
	if tool_required == VeyraItemCatalog.HANDS_ID:
		return equipped_tool == VeyraItemCatalog.HANDS_ID
	# Tool requirements define the minimum tier/type, not an exact item ID.
	return VeyraItemCatalog.is_tool_for_resource(equipped_tool, resource_type) and VeyraItemCatalog.is_tool_for_resource(tool_required, resource_type)

func get_interaction_requirement(player: Node) -> String:
	if not can_interact(player):
		if tool_required != VeyraItemCatalog.HANDS_ID:
			return VeyraItemCatalog.display_name(tool_required)
		return "Hands"
	return ""

func interact(player_override: Node = null) -> void:
	if depleted or remaining <= 0 or interaction_cooldown > 0.0:
		return

	var player: Node = player_override if player_override else get_tree().get_first_node_in_group("local_player")
	if not player:
		return

	var inventory: Node = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return

	var equipped_tool := VeyraItemCatalog.HANDS_ID
	if player.has_method("get_tool_id"):
		equipped_tool = player.get_tool_id()

	if not VeyraItemCatalog.is_valid_tool(equipped_tool):
		return
	if not VeyraItemCatalog.is_valid_tool(tool_required):
		return
	if tool_required == VeyraItemCatalog.HANDS_ID:
		if equipped_tool != VeyraItemCatalog.HANDS_ID:
			return
	elif not VeyraItemCatalog.is_tool_for_resource(equipped_tool, resource_type) or not VeyraItemCatalog.is_tool_for_resource(tool_required, resource_type):
		return

	var actual_tool_cost: float = VeyraItemCatalog.durability_cost(equipped_tool, resource_type)
	if actual_tool_cost > 0.0 and player.has_method("can_use_tool") and not player.can_use_tool(actual_tool_cost):
		return

	var yield_amount: int = maxi(1, int(round(tool_efficiency)))
	yield_amount += VeyraItemCatalog.gathering_bonus(equipped_tool, resource_type)
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("has_skill") and progression.has_skill("FIELDCRAFT"):
		yield_amount += 1
	yield_amount = mini(yield_amount, remaining)

	if not inventory.has_method("add_resource"):
		return

	var accepted := int(inventory.add_resource(resource_type, yield_amount))
	if accepted <= 0:
		return

	if actual_tool_cost > 0.0 and player.has_method("use_tool") and not player.use_tool(actual_tool_cost):
		inventory.remove_resource(resource_type, accepted)
		return

	remaining -= accepted
	progression = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("record_action"):
		progression.record_action("GATHER", accepted, resource_type)
	interaction_cooldown = 0.18
	set_process(true)
	if remaining <= 0:
		_deplete()

func get_interaction_point() -> Vector3:
	match node_kind:
		"stick":
			return global_position + Vector3.UP * 0.12
		"small_stone":
			return global_position + Vector3.UP * 0.18
		_:
			return global_position + Vector3.UP * 0.75

func get_interaction_text() -> String:
	if depleted or remaining <= 0:
		return "%s depleted" % resource_type
	match node_kind:
		"stick":
			return "Gather Sticks  [%d]" % remaining
		"small_stone":
			return "Gather Small Stones  [%d]" % remaining
		"large_stone":
			return "Mine Large Stone  [%d]" % remaining
		"tree":
			return "Harvest Tree  [%d]" % remaining
		"metal":
			return "Mine Metal  [%d]" % remaining
		"lux":
			return "Mine Lux  [%d]" % remaining
		_:
			return "Gather %s  [%d]" % [resource_type, remaining]

func _process(delta: float) -> void:
	if interaction_cooldown > 0.0:
		interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
	if not depleted:
		if interaction_cooldown <= 0.0:
			set_process(false)
		return
	respawn_time -= delta
	if respawn_time <= 0.0:
		_restore()

func _deplete() -> void:
	remaining = 0
	depleted = true
	respawn_time = maxf(1.0, respawn_seconds)
	set_process(true)
	visible = false
	if _visual_controller.is_valid():
		_visual_controller.call(false)
	collision_layer = 0
	collision_mask = 0

func _restore() -> void:
	remaining = maxi(0, amount)
	depleted = false
	respawn_time = 0.0
	set_process(false)
	visible = true
	if _visual_controller.is_valid():
		_visual_controller.call(true)
	collision_layer = 6 if physical_collision else 4
	collision_mask = 1

func get_save_state() -> Dictionary:
	if resource_id.is_empty() or (not depleted and remaining == amount):
		return {}
	return {
		"remaining": remaining,
		"depleted": depleted,
		"respawn_time": maxf(0.0, respawn_time)
	}

func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	remaining = clampi(int(state.get("remaining", amount)), 0, maxi(0, amount))
	depleted = bool(state.get("depleted", remaining <= 0))
	respawn_time = maxf(0.0, float(state.get("respawn_time", 0.0)))

	if depleted:
		set_process(true)
		visible = false
		if _visual_controller.is_valid():
			_visual_controller.call(false)
		collision_layer = 0
		collision_mask = 0
	else:
		set_process(false)
		visible = true
		collision_layer = 6 if physical_collision else 4
		collision_mask = 1
