extends CanvasLayer

const RESOURCE_TYPES: Array[String] = ["Stone", "Wood", "Metal", "Vitreous Lux", "Echo-Stone", "Meat", "Hide"]
const TOOL_ORDER: Array[String] = ["T00_HANDS", "I01_STONE_AXE", "I02_STONE_PICK"]

@onready var player: Node = get_parent()
@onready var inventory: Node = player.get_node_or_null("Inventory") if player else null
@onready var hotbar_label: Label = get_node_or_null("Hotbar/Label") as Label
@onready var hands_slot: Button = get_node_or_null("ToolHotbar/HandsSlot") as Button
@onready var axe_slot: Button = get_node_or_null("ToolHotbar/AxeSlot") as Button
@onready var pick_slot: Button = get_node_or_null("ToolHotbar/PickSlot") as Button
@onready var inventory_panel: Panel = get_node_or_null("InventoryPanel") as Panel
@onready var backpack_button: Button = get_node_or_null("BackpackButton") as Button
@onready var inventory_label: Label = get_node_or_null("InventoryPanel/Label") as Label
@onready var toast: Label = get_node_or_null("PickupToast") as Label

var toast_time: float = 0.0
var last_snapshot: Dictionary = {}
var resonance_panel: Panel
var resonance_label: Label
var resonance_seen := false

func _ready() -> void:
	if inventory and inventory.has_signal("inventory_changed"):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if player and player.has_signal("tool_changed"):
		player.tool_changed.connect(_on_tool_changed)
	if hands_slot and not hands_slot.pressed.is_connected(_select_hands):
		hands_slot.pressed.connect(_select_hands)
	if axe_slot and not axe_slot.pressed.is_connected(_select_axe):
		axe_slot.pressed.connect(_select_axe)
	if pick_slot and not pick_slot.pressed.is_connected(_select_pick):
		pick_slot.pressed.connect(_select_pick)
	if inventory and inventory.has_method("get_snapshot"):
		last_snapshot = inventory.get_snapshot()
	_build_resonance_hud()
	if player and player.has_signal("resonance_changed"):
		player.resonance_changed.connect(_on_resonance_changed)
	_refresh()
	if inventory_panel:
		inventory_panel.visible = false
	if backpack_button and not backpack_button.pressed.is_connected(_toggle_inventory):
		backpack_button.pressed.connect(_toggle_inventory)

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

func _on_resonance_changed(_charge: float, discovered: bool) -> void:
	if discovered and not resonance_seen:
		resonance_seen = true
		_show_toast("RESONANCE DISCOVERED")
	_refresh_resonance()

func _build_resonance_hud() -> void:
	resonance_panel = Panel.new()
	resonance_panel.name = "ResonanceHUD"
	resonance_panel.position = Vector2(24, 148)
	resonance_panel.size = Vector2(300, 54)
	resonance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.055, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.36, 0.25, 0.55, 0.62)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	resonance_panel.add_theme_stylebox_override("panel", style)
	add_child(resonance_panel)

	resonance_label = Label.new()
	resonance_label.position = Vector2(10, 7)
	resonance_label.size = Vector2(280, 40)
	resonance_label.add_theme_font_size_override("font_size", 13)
	resonance_panel.add_child(resonance_label)
	_refresh_resonance()

func _refresh_resonance() -> void:
	if not resonance_label or not inventory:
		return
	var charge: float = float(player.get_resonance()) if player and player.has_method("get_resonance") else 0.0
	var discovered: bool = bool(player.get("resonance_discovered")) if player else false
	if discovered:
		resonance_seen = true
	var lux: int = int(inventory.get_amount("Vitreous Lux"))
	var echo: int = int(inventory.get_amount("Echo-Stone"))
	if discovered or charge > 0.0:
		resonance_label.text = "RESONANCE  %02d%%   •   LUX %d   •   ECHO %d" % [int(round(charge)), lux, echo]
	else:
		resonance_label.text = "LUX %d   •   ECHO %d   •   ANOMALY UNKNOWN" % [lux, echo]

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
	_refresh_resonance()
	if inventory_label:
		inventory_label.text = _format_inventory(snapshot)
	var current := str(player.get_tool_id()) if player and player.has_method("get_tool_id") else "T00_HANDS"
	if hands_slot:
		hands_slot.disabled = false
		hands_slot.text = "1\nHANDS" if current != "T00_HANDS" else "1\nHANDS ✓"
	if axe_slot:
		axe_slot.disabled = not (inventory and inventory.has_item("I01_STONE_AXE"))
		axe_slot.text = "2\nAXE" if current != "I01_STONE_AXE" else "2\nAXE ✓"
	if pick_slot:
		pick_slot.disabled = not (inventory and inventory.has_item("I02_STONE_PICK"))
		pick_slot.text = "3\nPICK" if current != "I02_STONE_PICK" else "3\nPICK ✓"

func _select_hands() -> void:
	if player and player.has_method("set_tool"):
		player.set_tool("T00_HANDS")
		_refresh()

func _select_axe() -> void:
	if player and player.has_method("set_tool") and player.set_tool("I01_STONE_AXE"):
		_show_toast("Equipped Stone Axe")
		_refresh()

func _select_pick() -> void:
	if player and player.has_method("set_tool") and player.set_tool("I02_STONE_PICK"):
		_show_toast("Equipped Stone Pick")
		_refresh()

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
	for resource_type in ["Stone", "Wood", "Metal"]:
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
	lines.append("Echo-Stone     %d" % int(resources.get("Echo-Stone", 0)))
	lines.append("Vitreous Lux   %d" % int(resources.get("Vitreous Lux", 0)))
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
	if backpack_button:
		backpack_button.text = "CLOSE BAG" if inventory_panel and inventory_panel.visible else "BACKPACK"
