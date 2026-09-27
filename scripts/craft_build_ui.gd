extends CanvasLayer
class_name VeyraCraftBuildUI

var player: Node3D
var inventory: VeyraInventory
var crafting: VeyraCraftingManager
var building: VeyraBuildingManager

var panel: Panel
var title: Label
var status: Label
var tools_button: Button
var building_button: Button
var close_button: Button
var option_scroll: ScrollContainer
var option_list: VBoxContainer
var confirm_button: Button
var cancel_button: Button
var mode := ""
var selected_id := ""
var crafting_button: Button
var backdrop: ColorRect
var placement_hud: Panel
var placement_status: Label
var placement_place: Button
var placement_cancel: Button
var _option_buttons: Array[Button] = []
var _option_costs: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("modal_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	player = get_parent() as Node3D
	inventory = player.get_node_or_null("Inventory") as VeyraInventory
	crafting = get_node_or_null("/root/CraftingManager") as VeyraCraftingManager
	building = get_node_or_null("/root/BuildingManager") as VeyraBuildingManager
	_build_ui()
	set_process(false)

func is_modal_open() -> bool:
	return panel != null and panel.visible

func _process(_delta: float) -> void:
	if mode == "build" and building:
		var camera := get_viewport().get_camera_3d()
		building.update_from_camera(player, camera, inventory)
		_update_build_status()

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.48)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	add_child(backdrop)

	panel = Panel.new()
	panel.name = "CraftingPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.06, 0.97)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.30, 0.55, 0.60, 0.65)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	title = Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	status = Label.new()
	status.text = "Choose Tools or Building."
	status.add_theme_font_size_override("font_size", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(0, 38)
	box.add_child(status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)

	tools_button = Button.new()
	tools_button.text = "TOOLS"
	tools_button.custom_minimum_size = Vector2(0, 48)
	tools_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_button.pressed.connect(_show_crafting)
	tabs.add_child(tools_button)

	building_button = Button.new()
	building_button.text = "BUILDING"
	building_button.custom_minimum_size = Vector2(0, 48)
	building_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_button.pressed.connect(_show_building)
	tabs.add_child(building_button)

	option_scroll = ScrollContainer.new()
	option_scroll.name = "RecipeScroll"
	option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	option_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	option_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(option_scroll)

	option_list = VBoxContainer.new()
	option_list.add_theme_constant_override("separation", 8)
	option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_scroll.add_child(option_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	confirm_button = Button.new()
	confirm_button.text = "PLACE"
	confirm_button.custom_minimum_size = Vector2(0, 48)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_confirm_build)
	confirm_button.visible = false
	actions.add_child(confirm_button)

	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.custom_minimum_size = Vector2(0, 48)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_cancel_build)
	cancel_button.visible = false
	actions.add_child(cancel_button)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.pressed.connect(_close_panel)
	box.add_child(close_button)

	crafting_button = Button.new()
	crafting_button.name = "CraftingButton"
	crafting_button.text = "CRAFTING"
	crafting_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	crafting_button.offset_left = -178
	crafting_button.offset_right = -18
	crafting_button.offset_top = -190
	crafting_button.offset_bottom = -140
	crafting_button.pressed.connect(_toggle_panel)
	crafting_button.add_to_group("camera_blocking_ui")
	add_child(crafting_button)
	_build_placement_hud()
	_layout_panel()

func _build_placement_hud() -> void:
	placement_hud = Panel.new()
	placement_hud.name = "PlacementHUD"
	placement_hud.visible = false
	placement_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	placement_hud.add_to_group("camera_blocking_ui")
	add_child(placement_hud)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.06, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.65, 0.68, 0.70)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	placement_hud.add_theme_stylebox_override("panel", style)

	placement_status = Label.new()
	placement_status.text = "Move to a clear location."
	placement_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_status.add_theme_font_size_override("font_size", 14)
	placement_hud.add_child(placement_status)

	placement_place = Button.new()
	placement_place.text = "PLACE"
	placement_place.add_to_group("camera_blocking_ui")
	placement_place.pressed.connect(_confirm_build)
	placement_hud.add_child(placement_place)

	placement_cancel = Button.new()
	placement_cancel.text = "CANCEL"
	placement_cancel.add_to_group("camera_blocking_ui")
	placement_cancel.pressed.connect(_cancel_build)
	placement_hud.add_child(placement_cancel)
	_layout_placement_hud()

func _layout_placement_hud() -> void:
	if not placement_hud:
		return
	var size := get_viewport().get_visible_rect().size
	var width := minf(420.0, size.x - 24.0)
	placement_hud.size = Vector2(width, 112)
	placement_hud.position = Vector2((size.x - width) * 0.5, size.y - 132.0)
	placement_status.position = Vector2(12, 8)
	placement_status.size = Vector2(width - 24, 28)
	placement_place.position = Vector2(12, 48)
	placement_place.size = Vector2((width - 28) * 0.5, 48)
	placement_cancel.position = Vector2(16 + (width - 28) * 0.5, 48)
	placement_cancel.size = Vector2((width - 28) * 0.5, 48)

func _input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_panel()
		get_viewport().set_input_as_handled()

func _layout_panel() -> void:
	if not panel:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(560.0, maxf(320.0, viewport_size.x - 32.0))
	var height := minf(680.0, maxf(360.0, viewport_size.y - 32.0))
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - panel.size) * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_panel()
		_layout_placement_hud()

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		backdrop.visible = true
		crafting_button.visible = false
		mode = ""
		selected_id = ""
		confirm_button.visible = false
		cancel_button.visible = false
		set_process(false)
		if building:
			building.cancel_placement()
		if placement_hud:
			placement_hud.visible = false
		status.text = "Choose Tools or Building."
	else:
		_close_panel()

func _close_panel() -> void:
	if building:
		building.cancel_placement()
	panel.visible = false
	backdrop.visible = false
	crafting_button.visible = true
	if placement_hud:
		placement_hud.visible = false
	mode = ""
	set_process(false)

func _show_crafting() -> void:
	mode = "craft"
	confirm_button.visible = false
	cancel_button.visible = false
	set_process(false)
	_clear_options()
	status.text = "Simple tools for the player."
	for recipe_id in VeyraCraftingCatalog.all_recipe_ids():
		var recipe := VeyraCraftingCatalog.get_recipe(recipe_id)
		_add_recipe_option(
			str(recipe.get("name", recipe_id)),
			_format_cost(recipe.get("cost", {})),
			_has_cost(recipe.get("cost", {})),
			_craft.bind(recipe_id),
			recipe.get("cost", {})
		)

func _show_building() -> void:
	mode = "build"
	confirm_button.visible = false
	cancel_button.visible = true
	set_process(true)
	_clear_options()
	status.text = "Select a building, then find a clear location."
	for building_id in VeyraBuildingCatalog.all_building_ids():
		var definition := VeyraBuildingCatalog.get_building(building_id)
		_add_recipe_option(
			str(definition.get("name", building_id)),
			_format_cost(definition.get("cost", {})),
			_has_cost(definition.get("cost", {})),
			_select_building.bind(building_id),
			definition.get("cost", {})
		)

func _add_recipe_option(item_name: String, cost_text: String, affordable: bool, action: Callable, cost_data: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var button := Button.new()
	button.text = item_name
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Select %s" % item_name if affordable else "Missing materials"
	button.disabled = not affordable
	_style_option_button(button)
	button.pressed.connect(action)
	row.add_child(button)
	_option_buttons.append(button)
	_option_costs.append(cost_data)

	var cost := Label.new()
	cost.text = cost_text + ("  •  READY" if affordable else "  •  NEED MATERIALS")
	cost.add_theme_font_size_override("font_size", 13)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost.modulate = Color(0.52, 0.78, 0.58, 1.0) if affordable else Color(0.60, 0.64, 0.66, 1.0)
	row.add_child(cost)

	option_list.add_child(row)

func _craft(recipe_id: String) -> void:
	if not crafting or not inventory:
		return
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and bool(network_manager.get("session_active")) and not bool(network_manager.get("is_host")):
		network_manager.submit_local_craft(recipe_id)
		status.text = "Craft request sent."
		return
	if crafting.craft(recipe_id, inventory):
		var recipe := VeyraCraftingCatalog.get_recipe(recipe_id)
		status.text = "Crafted %s." % recipe.get("name", recipe_id)
		if player and player.has_method("set_tool") and recipe_id in ["I01_STONE_AXE", "I02_STONE_PICK"]:
			player.set_tool(recipe_id)
			status.text += " Equipped."
	else:
		status.text = "Need materials or inventory space."

func _select_building(building_id: String) -> void:
	selected_id = building_id
	if not building or not building.select_building(building_id):
		return
	panel.visible = false
	backdrop.visible = false
	crafting_button.visible = false
	mode = "build"
	set_process(true)
	placement_hud.visible = true
	placement_status.text = "Move to a clear location."
	placement_place.disabled = false

func _confirm_build() -> void:
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and bool(network_manager.get("session_active")) and not bool(network_manager.get("is_host")):
		if building:
			network_manager.submit_local_build(selected_id, building.placement_position)
		status.text = "Build request sent."
		_cancel_build()
		return
	if building and building.confirm_build(player, inventory):
		status.text = "Building placed."
		selected_id = ""
		confirm_button.visible = false
		_cancel_build()
	else:
		status.text = "Location invalid or materials missing."

func _cancel_build() -> void:
	if building:
		building.cancel_placement()
	mode = ""
	set_process(false)
	_clear_options()
	if placement_hud:
		placement_hud.visible = false
	confirm_button.visible = false
	cancel_button.visible = false
	if crafting_button:
		crafting_button.visible = true
	status.text = "Choose Tools or Building."

func _update_build_status() -> void:
	if not building:
		return
	var can_afford := building.has_required_materials(inventory)
	if building.placement_location_valid and can_afford:
		status.text = "Location ready. Tap PLACE."
		confirm_button.disabled = false
		if placement_status:
			placement_status.text = "Location ready. Tap PLACE."
			placement_place.disabled = false
	elif building.placement_location_valid:
		status.text = "Gather the listed materials."
		confirm_button.disabled = true
		if placement_status:
			placement_status.text = "Gather the listed materials."
			placement_place.disabled = true
	else:
		status.text = "Move to a clear location."
		confirm_button.disabled = true
		if placement_status:
			placement_status.text = "Move to a clear location."
			placement_place.disabled = true

func _has_cost(cost: Dictionary) -> bool:
	if not inventory:
		return false
	for key in cost.keys():
		if not inventory.has_resource(str(key), int(cost[key])):
			return false
	return true

func _clear_options() -> void:
	for child in option_list.get_children():
		child.queue_free()
	_option_buttons.clear()
	_option_costs.clear()

func _on_inventory_changed(_snapshot: Dictionary, _changed_type: String, _changed_amount: int) -> void:
	_refresh_option_affordability()

func _refresh_option_affordability() -> void:
	for index in range(_option_buttons.size()):
		var button := _option_buttons[index]
		if not button or not is_instance_valid(button):
			continue
		var affordable := _has_cost(_option_costs[index])
		button.disabled = not affordable
		button.tooltip_text = "Select %s" % button.text if affordable else "Missing materials"

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost.keys():
		parts.append("%s x%d" % [key, int(cost[key])])
	return " • ".join(parts)

func _style_option_button(button: Button, min_height: float = 48.0) -> void:
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

