extends CanvasLayer

const RESOURCE_TYPES: Array[String] = ["Stone", "Wood", "Metal", "Vitreous Lux", "Echo-Stone"]
const TOOL_ORDER: Array[String] = ["T00_HANDS", "I01_STONE_AXE", "I02_STONE_PICK"]

@onready var player: Node = get_parent()
@onready var inventory: Node = player.get_node_or_null("Inventory") if player else null
@onready var hotbar_label: Label = get_node_or_null("Hotbar/Label") as Label
@onready var tool_button: Button = get_node_or_null("ToolButton") as Button
@onready var inventory_panel: Panel = get_node_or_null("InventoryPanel") as Panel
@onready var inventory_label: Label = get_node_or_null("InventoryPanel/Label") as Label
@onready var toast: Label = get_node_or_null("PickupToast") as Label

var toast_time: float = 0.0
var last_snapshot: Dictionary = {}

func _ready() -> void:
	if inventory and inventory.has_signal("inventory_changed"):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if player and player.has_signal("tool_changed"):
		player.tool_changed.connect(_on_tool_changed)
	if tool_button and not tool_button.pressed.is_connected(_cycle_tool):
		tool_button.pressed.connect(_cycle_tool)
	if inventory and inventory.has_method("get_snapshot"):
		last_snapshot = inventory.get_snapshot()
	_refresh()
	if inventory_panel:
		inventory_panel.visible = false

func _process(delta: float) -> void:
	if toast_time <= 0.0:
		if toast:
			toast.visible = false
		return
	toast_time -= delta
	if toast_time <= 0.0 and toast:
		toast.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		_toggle_inventory()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		_cycle_tool()

func _on_tool_changed(_tool_id: String, _durability: float) -> void:
	_refresh()

func _on_inventory_changed(_snapshot: Dictionary, changed_type: String, changed_amount: int) -> void:
	_refresh()
	if changed_amount > 0:
		_show_toast("Picked up %s x%d" % [changed_type, changed_amount])

func _refresh() -> void:
	if not inventory or not inventory.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = inventory.get_snapshot()
	if hotbar_label:
		hotbar_label.text = _format_hotbar(snapshot)
	if inventory_label:
		inventory_label.text = _format_inventory(snapshot)
	if tool_button and player and player.has_method("get_tool_id"):
		var tool_id := str(player.get_tool_id())
		tool_button.text = "TOOL\n%s" % _tool_name(tool_id)
		tool_button.disabled = false

func _cycle_tool() -> void:
	if not player or not player.has_method("set_tool") or not inventory:
		return

	var current := str(player.get_tool_id()) if player.has_method("get_tool_id") else "T00_HANDS"
	var start_index := TOOL_ORDER.find(current)
	if start_index < 0:
		start_index = 0

	for step in range(1, TOOL_ORDER.size() + 1):
		var candidate := TOOL_ORDER[(start_index + step) % TOOL_ORDER.size()]
		if candidate != "T00_HANDS" and not inventory.has_item(candidate):
			continue
		if player.set_tool(candidate):
			_refresh()
			_show_toast("Equipped %s" % _tool_name(candidate))
			return

func _tool_name(tool_id: String) -> String:
	match tool_id:
		"I01_STONE_AXE":
			return "STONE AXE"
		"I02_STONE_PICK":
			return "STONE PICK"
		_:
			return "HANDS"

func _format_hotbar(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("resources", snapshot)
	var parts: Array[String] = []
	for resource_type in RESOURCE_TYPES:
		parts.append("%s  %d" % [_short_name(resource_type), int(resources.get(resource_type, 0))])
	return "  |  ".join(parts)

func _format_inventory(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("resources", snapshot)
	var items: Dictionary = snapshot.get("items", {})
	var lines: Array[String] = ["INVENTORY"]
	for resource_type in RESOURCE_TYPES:
		lines.append("%-14s %d" % [resource_type, int(resources.get(resource_type, 0))])
	for item_id in items.keys():
		lines.append("%-14s %d" % [VeyraItemCatalog.display_name(str(item_id)), int(items[item_id])])
	var total: int = 0
	for value in resources.values():
		total += int(value)
	for value in items.values():
		total += int(value)
	var capacity: Dictionary = inventory.get_capacity_state() if inventory.has_method("get_capacity_state") else {}
	lines.append("")
	lines.append("TOTAL ITEMS: %d" % total)
	if not capacity.is_empty():
		lines.append("WEIGHT: %.1f / %.1f" % [float(capacity.get("weight", 0.0)), float(capacity.get("weight_max", 0.0))])
		lines.append("SLOTS: %d / %d" % [int(capacity.get("slots_used", 0)), int(capacity.get("slots_max", 0))])
	lines.append("")
	lines.append("I = Inventory   Q = Cycle Tool")
	return "\n".join(lines)

func _short_name(resource_type: String) -> String:
	match resource_type:
		"Vitreous Lux":
			return "LUX"
		_:
			return resource_type.to_upper()

func _show_toast(message: String) -> void:
	if not toast:
		return
	toast.text = message
	toast.visible = true
	toast_time = 2.0

func _toggle_inventory() -> void:
	if inventory_panel:
		inventory_panel.visible = not inventory_panel.visible
