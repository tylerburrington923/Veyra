extends CanvasLayer

const RESOURCE_TYPES: Array[String] = ["Stone", "Wood", "Metal", "Refined Metal", "Vitreous Lux", "Echo-Stone", "Meat", "Hide", "Leather", "Food"]
const TOOL_ORDER: Array[String] = ["T00_HANDS", "I01_STONE_AXE", "I02_STONE_PICK", "I08_HUNTER_KNIFE", "I09_STONE_SPEAR", "I04_METAL_AXE", "I05_METAL_PICK", "I10_METAL_SPEAR", "I06_ECHO_AXE", "I07_ECHO_PICK"]

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
	if player and player.has_signal("resonance_tier_changed"):
		player.resonance_tier_changed.connect(_on_resonance_tier_changed)
	_refresh()
	_polish_hud()
	if inventory_panel:
		inventory_panel.visible = false
	if backpack_button and not backpack_button.pressed.is_connected(_toggle_inventory):
		backpack_button.pressed.connect(_toggle_inventory)

func _polish_hud() -> void:
	# Keep the persistent HUD compact and non-overlapping on phone aspect ratios.
	if backpack_button:
		backpack_button.text = "PACK"
		backpack_button.size = Vector2(96, 42)
		_style_hud_button(backpack_button)
	if hotbar_label:
		hotbar_label.add_theme_font_size_override("font_size", 13)
	if resonance_panel:
		resonance_panel.position = Vector2(24, 120)
		resonance_panel.size = Vector2(320, 48)
	if hands_slot:
		hands_slot.custom_minimum_size = Vector2(94, 64)
	if axe_slot:
		axe_slot.custom_minimum_size = Vector2(94, 64)
	if pick_slot:
		pick_slot.custom_minimum_size = Vector2(94, 64)
	if inventory_panel:
		inventory_panel.position = Vector2(20, 110)
		inventory_panel.size = Vector2(330, 470)

func _style_hud_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.08, 0.90)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.25, 0.58, 0.62, 0.55)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(0.06, 0.16, 0.18, 0.96)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.24, 0.26, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.90, 0.96, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 15)

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

func _on_resonance_tier_changed(_tier: int, tier_name: String) -> void:
	_show_toast("RESONANCE: %s" % tier_name)
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
	var discovered: bool = (player.get("resonance_discovered") == true) if player else false
	if discovered:
		resonance_seen = true
	var lux: int = int(inventory.get_amount("Vitreous Lux"))
	var echo: int = int(inventory.get_amount("Echo-Stone"))
	var tier_name := "DORMANT"
	if player and player.has_method("get_resonance_tier_name"):
		tier_name = str(player.get_resonance_tier_name())
	if discovered or charge > 0.0:
		resonance_label.text = "%s  •  %02d%%   •   LUX %d   •   ECHO %d" % [tier_name, int(round(charge)), lux, echo]
	else:
		resonance_label.text = "LUX %d   •   ECHO %d   •   ANOMALY UNKNOWN" % [lux, echo]

func _on_tool_changed(_tool_id: String, _durability: float) -> void:
	_refresh()

func _on_inventory_changed(_snapshot: Dictionary, changed_type: String, changed_amount: int) -> void:
	_refresh()
	if inventory_panel and inventory_panel.visible:
		_build_inventory_grid()
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
		"I04_METAL_AXE":
			return "METAL AXE"
		"I05_METAL_PICK":
			return "METAL PICK"
		"I06_ECHO_AXE":
			return "ECHO AXE"
		"I07_ECHO_PICK":
			return "ECHO PICK"
		_:
			return "HANDS"

func _format_hotbar(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("resources", snapshot)
	var parts: Array[String] = []
	for resource_type in ["Stone", "Wood", "Metal", "Vitreous Lux"]:
		parts.append("%s  %d" % [_short_name(resource_type), int(resources.get(resource_type, 0))])
	parts.append("COINS  %d" % int(snapshot.get("coins", 0)))
	return "  |  ".join(parts)

func _format_inventory(snapshot: Dictionary) -> String:
	var resources: Dictionary = snapshot.get("resources", snapshot)
	var items: Dictionary = snapshot.get("items", {})
	var lines: Array[String] = ["INVENTORY", "Coins          %d" % int(snapshot.get("coins", 0))]
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
		if inventory_panel.visible:
			_build_inventory_grid()
	if backpack_button:
		backpack_button.text = "CLOSE" if inventory_panel and inventory_panel.visible else "PACK"

func _build_inventory_grid() -> void:
	if not inventory_panel or not inventory:
		return
	var old_grid := inventory_panel.get_node_or_null("InventoryGrid")
	if old_grid:
		old_grid.queue_free()
	var old_capacity := inventory_panel.get_node_or_null("CapacityLabel")
	if old_capacity:
		old_capacity.queue_free()
	if inventory_label:
		inventory_label.visible = true
		inventory_label.text = "BACKPACK"
		inventory_label.position = Vector2(14, 10)
		inventory_label.size = Vector2(300, 30)
		inventory_label.add_theme_font_size_override("font_size", 20)
	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = 4
	grid.position = Vector2(14, 48)
	grid.size = Vector2(308, 348)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.add_child(grid)
	var snapshot: Dictionary = inventory.get_snapshot()
	var resources: Dictionary = snapshot.get("resources", {})
	var items: Dictionary = snapshot.get("items", {})
	var stacks: Array[Dictionary] = []
	for resource_type in RESOURCE_TYPES:
		var amount := int(resources.get(resource_type, 0))
		if amount > 0:
			stacks.append({"id": resource_type, "amount": amount, "kind": "resource"})
	for item_id in VeyraItemCatalog.ITEM_TYPES:
		var amount := int(items.get(item_id, 0))
		if amount > 0:
			stacks.append({"id": item_id, "amount": amount, "kind": "item"})
	var max_slots := int(inventory.get("max_slots"))
	for slot_index in range(max_slots):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(72, 58)
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_to_group("camera_blocking_ui")
		_style_inventory_slot(slot)
		if slot_index < stacks.size():
			var stack: Dictionary = stacks[slot_index]
			var id := str(stack.get("id", ""))
			var amount := int(stack.get("amount", 0))
			var kind := str(stack.get("kind", "resource"))
			slot.text = _inventory_slot_text(id, amount)
			slot.tooltip_text = _inventory_slot_tooltip(id, amount)
			if kind == "item":
				if VeyraItemCatalog.is_valid_tool(id) or id in VeyraItemCatalog.ARMOR_IDS:
					slot.pressed.connect(_equip_inventory_item.bind(id))
		else:
			slot.text = ""
		grid.add_child(slot)
	var capacity: Dictionary = inventory.get_capacity_state()
	var capacity_label := Label.new()
	capacity_label.name = "CapacityLabel"
	capacity_label.position = Vector2(14, 404)
	capacity_label.size = Vector2(308, 36)
	capacity_label.text = "SLOTS %d/%d   •   WEIGHT %.1f/%.1f" % [
		int(capacity.get("slots_used", 0)), int(capacity.get("slots_max", 0)),
		float(capacity.get("weight", 0.0)), float(capacity.get("weight_max", 0.0))
	]
	capacity_label.add_theme_font_size_override("font_size", 12)
	inventory_panel.add_child(capacity_label)

func _inventory_slot_text(id: String, amount: int) -> String:
	if VeyraItemCatalog.is_valid(id):
		var name := VeyraItemCatalog.display_name(id).replace("Stone ", "")
		return "%s\nx%d" % [name.to_upper(), amount]
	return "%s\nx%d" % [id.to_upper(), amount]

func _inventory_slot_tooltip(id: String, amount: int) -> String:
	if VeyraItemCatalog.is_valid(id):
		return "%s x%d\nTap to equip" % [VeyraItemCatalog.display_name(id), amount]
	return "%s x%d" % [id, amount]

func _equip_inventory_item(item_id: String) -> void:
	if not player:
		return
	var equipped := false
	if item_id in VeyraItemCatalog.ARMOR_IDS and player.has_method("equip_armor"):
		equipped = bool(player.equip_armor(item_id))
	elif player.has_method("set_tool"):
		equipped = bool(player.set_tool(item_id))
	if equipped:
		_show_toast("Equipped %s" % VeyraItemCatalog.display_name(item_id))
		_refresh()

func _style_inventory_slot(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.055, 0.065, 0.96)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.24, 0.38, 0.40, 0.8)
	normal.corner_radius_top_left = 7
	normal.corner_radius_top_right = 7
	normal.corner_radius_bottom_left = 7
	normal.corner_radius_bottom_right = 7
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.22, 0.24, 1.0)
	pressed.border_color = Color(0.42, 0.78, 0.78, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.88, 0.94, 0.94, 1.0))
	button.add_theme_font_size_override("font_size", 11)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_polish_hud()
		if inventory_panel and inventory_panel.visible:
			_build_inventory_grid()
