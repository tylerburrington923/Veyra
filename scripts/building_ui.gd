extends CanvasLayer
class_name VeyraBuildingUI

var panel: Panel
var title_label: Label
var body_scroll: ScrollContainer
var body_box: VBoxContainer
var close_button: Button
var _building: Node
var _player: Node
var _mode := ""
var _backdrop: ColorRect
var _townhall_buttons: Dictionary = {}
var _logistics_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("building_ui")
	layer = 200
	_build_base()
	visible = false

func open_campfire(building: Node, player: Node) -> void:
	_open(building, player, "CAMPFIRE")
	_add_text("Add wood to keep the fire burning. Cook meat while the fire is hot.")
	_add_action("ADD WOOD", _campfire_action)
	_add_action("COOK 2 MEAT → 1 FOOD", _cook_meat_action)

func open_tannery(building: Node, player: Node) -> void:
	_open(building, player, "TANNERY")
	_add_text("Process animal Hide into Leather for advanced equipment.")
	_add_action("PROCESS 2 HIDE → 1 LEATHER", _tannery_action)
	_refresh_tannery()

func open_storage(building: Node, player: Node) -> void:
	_open(building, player, "STORAGE")
	_refresh_storage()

func open_townhall(building: Node, player: Node) -> void:
	_open(building, player, "TOWN HALL")
	_add_text("SETTLEMENT COMMAND")
	_add_or_update_status("Loading settlement status...")
	_add_action("DEPOSIT CIVIC 10 WOOD + 10 STONE", _deposit_civic_materials)
	_add_action("DEPOSIT ALL BUILD MATERIALS", _deposit_build_materials)
	_add_text("FOUNDATIONS COST NOTHING. Deliver materials yourself at the foundation, or dispatch a worker from Town Hall logistics.")
	_add_text("Build new structures from the list below. Town Hall itself is excluded because each settlement has one civic anchor.")
	_townhall_buttons.clear()
	_logistics_buttons.clear()
	for building_id in VeyraBuildingCatalog.all_building_ids():
		if building_id == "B05_TOWNHALL":
			continue
		var definition := VeyraBuildingCatalog.get_building(building_id)
		_add_build_option(building_id, definition)
	_refresh_townhall()
	_build_logistics_controls()

func open_blacksmith(building: Node, player: Node) -> void:
	_open(building, player, "BLACKSMITH")
	_add_text("Refine raw Metal into Refined Metal, then forge durable tools.")
	_add_action("REFINE 2 METAL → 1 REFINED", _refine_action)
	_add_action("FORGE STONE AXE", _forge_axe)
	_add_action("FORGE STONE PICK", _forge_pick)
	_add_action("FORGE METAL AXE", _forge_metal_axe)
	_add_action("FORGE METAL PICK", _forge_metal_pick)
	_add_action("FORGE ECHO AXE", _forge_echo_axe)
	_add_action("FORGE ECHO PICK", _forge_echo_pick)

func close_ui() -> void:
	visible = false
	if _backdrop:
		_backdrop.visible = false
	_building = null
	_player = null
	_mode = ""
	_townhall_buttons.clear()

func is_modal_open() -> bool:
	return visible

func _process(_delta: float) -> void:
	if not visible:
		return
	if _mode == "campfire":
		_refresh_campfire()
	elif _mode == "townhall":
		_refresh_townhall()
	elif _mode == "storage":
		# Storage is refreshed after explicit transactions, not every frame.
		pass
	elif _mode == "blacksmith":
		_refresh_blacksmith()
	elif _mode == "tannery":
		_refresh_tannery()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_ui()
		get_viewport().set_input_as_handled()

func _open(building: Node, player: Node, title_text: String) -> void:
	_building = building
	_player = player
	title_label.text = title_text
	_mode = "campfire" if title_text == "CAMPFIRE" else ("storage" if title_text == "STORAGE" else ("townhall" if title_text == "TOWN HALL" else ("tannery" if title_text == "TANNERY" else "blacksmith")))
	_clear_body()
	visible = true
	_backdrop.visible = true
	get_viewport().set_input_as_handled()

func _build_base() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "ModalBackdrop"
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.48)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.add_to_group("camera_blocking_ui")
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_backdrop)

	panel = Panel.new()
	panel.name = "BuildingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_to_group("camera_blocking_ui")
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.055, 0.985)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.62, 0.66, 0.75)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", style)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 23)
	panel.add_child(title_label)

	body_scroll = ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.follow_focus = true
	body_scroll.scroll_deadzone = 18
	panel.add_child(body_scroll)
	body_box = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 8)
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body_box)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.pressed.connect(close_ui)
	_style_button(close_button)
	panel.add_child(close_button)
	_layout_panel()

func _layout_panel() -> void:
	var size := get_viewport().get_visible_rect().size
	var width := minf(520.0, maxf(300.0, size.x - 24.0))
	var height := minf(620.0, maxf(300.0, size.y - 24.0))
	panel.size = Vector2(width, height)
	panel.position = (size - panel.size) * 0.5
	_backdrop.size = size
	_backdrop.position = Vector2.ZERO
	title_label.position = Vector2(16, 12)
	title_label.size = Vector2(width - 112, 38)
	body_scroll.position = Vector2(16, 58)
	body_scroll.size = Vector2(width - 32, height - 122)
	close_button.position = Vector2(width - 96, 10)
	close_button.size = Vector2(80, 40)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_panel()

func _clear_body() -> void:
	for child in body_box.get_children():
		child.queue_free()

func _add_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color(0.72, 0.78, 0.80, 1.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.add_child(label)

func _add_action(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_style_button(button)
	body_box.add_child(button)

func _add_build_option(id: String, definition: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.name = "Build_%s" % id
	button.text = str(definition.get("name", id))
	button.tooltip_text = "Select %s" % button.text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_begin_build.bind(id))
	_style_button(button)
	row.add_child(button)
	_townhall_buttons[id] = button
	var cost := Label.new()
	cost.text = _format_cost(definition.get("cost", {}))
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.add_theme_font_size_override("font_size", 13)
	row.add_child(cost)
	body_box.add_child(row)

func _begin_build(building_id: String) -> void:
	var manager := get_node_or_null("/root/BuildingManager") as VeyraBuildingManager
	if not manager or not manager.select_building(building_id):
		return
	close_ui()

func _deposit_civic_materials() -> void:
	if _request_remote_action("TOWNHALL_CIVIC"):
		return
	if _building and _building.has_method("deposit_civic_materials"):
		_building.deposit_civic_materials(_player, 10)
		_refresh_townhall()

func _deposit_build_materials() -> void:
	if _request_remote_action("TOWNHALL_DEPOSIT"):
		return
	if _building and _building.has_method("deposit_build_materials"):
		_building.deposit_build_materials(_player)
		_refresh_townhall()

func _build_logistics_controls() -> void:
	var logistics := get_node_or_null("/root/BuildSiteManager") as VeyraBuildSiteManager
	if not logistics:
		return
	for site_id in logistics.get_all_sites().keys():
		var site: Dictionary = logistics.get_site(str(site_id))
		var definition := VeyraBuildingCatalog.get_building(str(site.get("building_type", "")))
		var remaining := logistics.get_remaining_materials(str(site_id))
		_add_text("%s  •  %d%% delivered" % [str(definition.get("name", "Build Site")), int(round(logistics.get_completion_ratio(str(site_id)) * 100.0))])
		_add_action("DISPATCH WORKER  •  %s" % _format_cost(remaining), _dispatch_site.bind(str(site_id)))
		_logistics_buttons[str(site_id)] = true

func _dispatch_site(site_id: String) -> void:
	var logistics := get_node_or_null("/root/BuildSiteManager") as VeyraBuildSiteManager
	if not logistics:
		return
	var remaining := logistics.get_remaining_materials(site_id)
	var network := get_node_or_null("/root/NetworkManager")
	if network and bool(network.get("session_active")) and not bool(network.get("is_host")):
		network.submit_local_worker_delivery(site_id, remaining)
		_add_or_update_status("Worker delivery request sent to host.")
		return
	var order_id := str(logistics.dispatch_available_worker(site_id, remaining))
	_add_or_update_status("Worker dispatched." if not order_id.is_empty() else "No worker or Town Hall materials available.")

func _campfire_action() -> void:
	if _request_remote_action("CAMPFIRE_FUEL"):
		return
	if _building and _building.has_method("add_campfire_fuel"):
		_building.add_campfire_fuel(_player, 1)
	_refresh_campfire()

func _cook_meat_action() -> void:
	if _request_remote_action("CAMPFIRE_COOK"):
		return
	if _building and _building.has_method("cook_meat"):
		_building.cook_meat(_player)
	_refresh_campfire()

func _tannery_action() -> void:
	if _request_remote_action("TANNERY_PROCESS"):
		return
	if _building and _building.has_method("refine_hide_to_leather"):
		_building.refine_hide_to_leather(_player)
	_refresh_tannery()

func _refine_action() -> void:
	if _request_remote_action("BLACKSMITH_REFINE"):
		return
	if _building and _building.has_method("blacksmith_refine"):
		_building.blacksmith_refine(_player)
		_refresh_blacksmith()

func _forge_axe() -> void:
	if _request_remote_action("BLACKSMITH_FORGE", "I01_STONE_AXE"):
		return
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I01_STONE_AXE")
		_refresh_blacksmith()

func _forge_metal_axe() -> void:
	if _request_remote_action("BLACKSMITH_FORGE", "I04_METAL_AXE"):
		return
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I04_METAL_AXE")
		_refresh_blacksmith()

func _forge_metal_pick() -> void:
	if _request_remote_action("BLACKSMITH_FORGE", "I05_METAL_PICK"):
		return
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I05_METAL_PICK")
		_refresh_blacksmith()

func _forge_echo_axe() -> void:
	if _request_remote_action("BLACKSMITH_FORGE", "I06_ECHO_AXE"):
		return
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I06_ECHO_AXE")
		_refresh_blacksmith()

func _forge_echo_pick() -> void:
	if _request_remote_action("BLACKSMITH_FORGE", "I07_ECHO_PICK"):
		return
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I07_ECHO_PICK")
		_refresh_blacksmith()

func _forge_pick() -> void:
	if _request_remote_action("BLACKSMITH_FORGE", "I02_STONE_PICK"):
		return
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I02_STONE_PICK")
		_refresh_blacksmith()

func _refresh_campfire() -> void:
	if not _building:
		return
	var heat := float(_building.get_campfire_heat()) if _building.has_method("get_campfire_heat") else 0.0
	_add_or_update_status("Heat remaining: %.0f sec" % heat)

func _get_storage_snapshot() -> Dictionary:
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement or not settlement.has_method("get_building_storage"):
		return {"resources": {}, "items": {}}
	var storage: Dictionary = settlement.get_building_storage(_building.building_id)
	if not (storage.get("resources", {}) is Dictionary):
		storage["resources"] = {}
	if not (storage.get("items", {}) is Dictionary):
		storage["items"] = {}
	return storage

func _refresh_storage() -> void:
	if _mode != "storage" or not _building or not _player:
		return
	_clear_body()
	_add_text("PERSONAL TOOLS STAY WITH YOU.\nResources and non-tool items can be stored here.")
	_add_action("DEPOSIT ALL", _deposit_storage)
	_add_action("WITHDRAW ALL", _withdraw_storage)
	var storage := _get_storage_snapshot()
	var resources: Dictionary = storage.get("resources", {})
	var items: Dictionary = storage.get("items", {})
	var lines: Array[String] = []
	for key in resources.keys():
		var amount := int(resources[key])
		if amount > 0:
			lines.append("%s  x%d" % [str(key), amount])
	for key in items.keys():
		var amount := int(items[key])
		if amount > 0:
			lines.append("%s  x%d" % [VeyraItemCatalog.display_name(str(key)), amount])
	_add_text("STORED\n" + ("\n".join(lines) if not lines.is_empty() else "Storage is empty."))

func _deposit_storage() -> void:
	if _request_remote_action("STORAGE_DEPOSIT"):
		return
	var inventory := _player.get_node_or_null("Inventory") as VeyraInventory
	var settlement := get_node_or_null("/root/SettlementManager")
	if not inventory or not settlement:
		return
	var storage := _get_storage_snapshot()
	var stored_resources: Dictionary = storage.get("resources", {})
	var stored_items: Dictionary = storage.get("items", {})
	for resource_type in inventory.get_resource_types():
		var amount := inventory.get_amount(resource_type)
		if amount > 0:
			var removed := inventory.remove_resource(resource_type, amount)
			if removed > 0:
				stored_resources[resource_type] = int(stored_resources.get(resource_type, 0)) + removed
	for item_id in inventory.get_item_types():
		if VeyraItemCatalog.is_valid_tool(item_id):
			continue
		var amount := inventory.get_item_amount(item_id)
		if amount > 0:
			var removed := inventory.remove_item(item_id, amount)
			if removed > 0:
				stored_items[item_id] = int(stored_items.get(item_id, 0)) + removed
	storage["resources"] = stored_resources
	storage["items"] = stored_items
	settlement.set_building_storage(_building.building_id, storage)
	_refresh_storage()

func _withdraw_storage() -> void:
	if _request_remote_action("STORAGE_WITHDRAW"):
		return
	var inventory := _player.get_node_or_null("Inventory") as VeyraInventory
	var settlement := get_node_or_null("/root/SettlementManager")
	if not inventory or not settlement:
		return
	var storage := _get_storage_snapshot()
	var stored_resources: Dictionary = storage.get("resources", {})
	var stored_items: Dictionary = storage.get("items", {})
	for resource_type in stored_resources.keys().duplicate():
		var amount := int(stored_resources[resource_type])
		if amount <= 0:
			stored_resources.erase(resource_type)
			continue
		var accepted := inventory.add_resource(str(resource_type), amount)
		stored_resources[resource_type] = amount - accepted
		if stored_resources[resource_type] <= 0:
			stored_resources.erase(resource_type)
	for item_id in stored_items.keys().duplicate():
		var amount := int(stored_items[item_id])
		if amount <= 0:
			stored_items.erase(item_id)
			continue
		var accepted := inventory.add_item(str(item_id), amount)
		stored_items[item_id] = amount - accepted
		if stored_items[item_id] <= 0:
			stored_items.erase(item_id)
	storage["resources"] = stored_resources
	storage["items"] = stored_items
	settlement.set_building_storage(_building.building_id, storage)
	_refresh_storage()


func _refresh_townhall() -> void:
	if _mode != "townhall" or not _player:
		return
	var inventory: VeyraInventory = _player.get_inventory() if _player.has_method("get_inventory") else null
	var settlement := get_node_or_null("/root/SettlementManager")
	if settlement and settlement.has_method("get_settlement_state"):
		var state: Dictionary = settlement.get_settlement_state()
		var civic_stock: Dictionary = state.get("stock", {})
		_add_or_update_status(
			"Population %d  •  Food %d  •  Water %d  •  Wood %d  •  Stone %d" % [
				int(state.get("population", 0)),
				int(civic_stock.get("food", 0)),
				int(civic_stock.get("water", 0)),
				int(civic_stock.get("wood", 0)),
				int(civic_stock.get("stone", 0))
			]
		)
	if not inventory:
		return
	for building_id in _townhall_buttons.keys():
		var button := _townhall_buttons[building_id] as Button
		if not button:
			continue
		var definition := VeyraBuildingCatalog.get_building(str(building_id))
		button.disabled = false
		button.tooltip_text = "Place free foundation for %s" % button.text

func _can_afford(inventory: VeyraInventory, cost: Dictionary) -> bool:
	for resource_type in cost.keys():
		if not inventory.has_resource(str(resource_type), int(cost[resource_type])):
			return false
	return true

func _missing_cost(inventory: VeyraInventory, cost: Dictionary) -> String:
	var missing: Array[String] = []
	for resource_type in cost.keys():
		var required := int(cost[resource_type])
		var have := int(inventory.get_amount(str(resource_type)))
		if have < required:
			missing.append("%s %d/%d" % [str(resource_type), have, required])
	return " • ".join(missing)

func _request_remote_action(action: String, argument: String = "") -> bool:
	var network := get_node_or_null("/root/NetworkManager")
	if not network or not bool(network.get("session_active")) or bool(network.get("is_host")):
		return false
	if _building and network.has_method("submit_local_building_action"):
		network.submit_local_building_action(str(_building.get("building_id")), action, argument)
		_add_or_update_status("Request sent to host.")
		return true
	return false

func perform_remote_action(building: Node, player: Node, action: String, argument: String = "") -> void:
	_building = building
	_player = player
	match action:
		"TOWNHALL_CIVIC":
			if _building and _building.has_method("deposit_civic_materials"):
				_building.deposit_civic_materials(_player, 10)
		"TOWNHALL_DEPOSIT":
			if _building and _building.has_method("deposit_build_materials"):
				_building.deposit_build_materials(_player)
		"STORAGE_DEPOSIT":
			_deposit_storage()
		"STORAGE_WITHDRAW":
			_withdraw_storage()
		"CAMPFIRE_FUEL":
			if _building and _building.has_method("add_campfire_fuel"):
				_building.add_campfire_fuel(_player, 1)
		"CAMPFIRE_COOK":
			if _building and _building.has_method("cook_meat"):
				_building.cook_meat(_player)
		"TANNERY_PROCESS":
			if _building and _building.has_method("refine_hide_to_leather"):
				_building.refine_hide_to_leather(_player)
		"BLACKSMITH_REFINE":
			if _building and _building.has_method("blacksmith_refine"):
				_building.blacksmith_refine(_player)
		"BLACKSMITH_FORGE":
			if _building and _building.has_method("blacksmith_forge"):
				_building.blacksmith_forge(_player, argument)

func _refresh_tannery() -> void:
	if _mode != "tannery" or not _player:
		return
	var inventory: VeyraInventory = _player.get_inventory() if _player.has_method("get_inventory") else null
	if not inventory:
		return
	_add_or_update_status("HIDE %d  •  LEATHER %d" % [inventory.get_amount("Hide"), inventory.get_amount("Leather")])

func _refresh_blacksmith() -> void:
	if _mode != "blacksmith" or not _player:
		return
	var inventory: VeyraInventory = _player.get_inventory() if _player.has_method("get_inventory") else null
	if not inventory:
		return
	_add_or_update_status(
		"METAL %d  •  REFINED %d  •  WOOD %d  •  STONE %d" % [
			inventory.get_amount("Metal"),
			inventory.get_amount("Refined Metal"),
			inventory.get_amount("Wood"),
			inventory.get_amount("Stone")
		]
	)

func _add_or_update_status(text: String) -> void:
	var status := body_box.get_node_or_null("Status") as Label
	if not status:
		status = Label.new()
		status.name = "Status"
		status.add_theme_font_size_override("font_size", 14)
		body_box.add_child(status)
	status.text = text

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost.keys():
		parts.append("%s x%d" % [key, int(cost[key])])
	return "Cost: " + " • ".join(parts)

func _style_button(button: Button, min_height: float = 48.0) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.095, 0.115, 0.98)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.28, 0.58, 0.62, 0.72)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.09, 0.18, 0.21, 1.0)
	hover.border_color = Color(0.38, 0.78, 0.82, 0.95)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.13, 0.29, 0.31, 1.0)
	pressed.border_color = Color(0.46, 0.88, 0.86, 1.0)
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 8
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = Color(0.50, 0.90, 0.88, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.045, 0.06, 0.065, 0.78)
	disabled.border_color = Color(0.20, 0.24, 0.25, 0.45)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.90, 0.96, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.98, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.50, 0.51, 1.0))
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, min_height)

