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

func _ready() -> void:
	player = get_parent() as Node3D
	inventory = player.get_node_or_null("Inventory") as VeyraInventory
	crafting = get_node_or_null("/root/CraftingManager") as VeyraCraftingManager
	building = get_node_or_null("/root/BuildingManager") as VeyraBuildingManager
	_build_ui()
	set_process(false)

func _process(_delta: float) -> void:
	if mode == "build" and building:
		var camera := get_viewport().get_camera_3d()
		building.update_from_camera(player, camera, inventory)
		_update_build_status()

func _build_ui() -> void:
	panel = Panel.new()
	panel.name = "CraftingPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -350
	panel.offset_right = -18
	panel.offset_top = -270
	panel.offset_bottom = 220
	panel.visible = false
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
	add_child(crafting_button)

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		mode = ""
		selected_id = ""
		confirm_button.visible = false
		cancel_button.visible = false
		set_process(false)
		if building:
			building.cancel_placement()
		status.text = "Choose Tools or Building."
	else:
		_close_panel()

func _close_panel() -> void:
	if building:
		building.cancel_placement()
	panel.visible = false
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
			_craft.bind(recipe_id)
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
			_select_building.bind(building_id)
		)

func _add_recipe_option(item_name: String, cost_text: String, affordable: bool, action: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var button := Button.new()
	button.text = item_name
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	row.add_child(button)

	var cost := Label.new()
	cost.text = cost_text + ("  •  READY" if affordable else "")
	cost.add_theme_font_size_override("font_size", 13)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost.modulate = Color(0.70, 0.76, 0.78, 1.0) if not affordable else Color(0.52, 0.78, 0.58, 1.0)
	row.add_child(cost)

	option_list.add_child(row)

func _craft(recipe_id: String) -> void:
	if not crafting or not inventory:
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
	if building and building.select_building(building_id):
		status.text = "Move to a clear location."
		confirm_button.visible = true
		confirm_button.disabled = false

func _confirm_build() -> void:
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
	confirm_button.visible = false
	cancel_button.visible = false
	status.text = "Choose Tools or Building."

func _update_build_status() -> void:
	if not building:
		return
	var can_afford := building.has_required_materials(inventory)
	if building.placement_location_valid and can_afford:
		status.text = "Location ready. Tap PLACE."
		confirm_button.disabled = false
	elif building.placement_location_valid:
		status.text = "Gather the listed materials."
		confirm_button.disabled = true
	else:
		status.text = "Move to a clear location."
		confirm_button.disabled = true

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

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost.keys():
		parts.append("%s x%d" % [key, int(cost[key])])
	return " • ".join(parts)
