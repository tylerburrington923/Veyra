extends CanvasLayer
class_name VeyraCraftBuildUI

var player: Node3D
var inventory: VeyraInventory
var crafting: VeyraCraftingManager
var building: VeyraBuildingManager

var panel: Panel
var title: Label
var status: Label
var action_row: HBoxContainer
var craft_button: Button
var build_button: Button
var close_button: Button
var option_panel: Panel
var option_list: VBoxContainer
var confirm_button: Button
var cancel_button: Button
var mode := ""
var selected_id := ""
var workshop_button: Button

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
	panel.name = "CraftBuildPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-310, -210)
	panel.size = Vector2(290, 420)
	panel.visible = false
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.08, 0.94)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.30, 0.55, 0.60, 0.65)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel.add_theme_stylebox_override("panel", panel_style)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.size = Vector2(258, 388)
	panel.add_child(box)

	title = Label.new()
	title.text = "WORKSHOP"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	status = Label.new()
	status.text = "Choose an action."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	action_row = HBoxContainer.new()
	box.add_child(action_row)

	craft_button = Button.new()
	craft_button.text = "CRAFT"
	craft_button.custom_minimum_size = Vector2(120, 52)
	craft_button.pressed.connect(_show_crafting)
	action_row.add_child(craft_button)

	build_button = Button.new()
	build_button.text = "BUILD"
	build_button.custom_minimum_size = Vector2(120, 52)
	build_button.pressed.connect(_show_building)
	action_row.add_child(build_button)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(240, 48)
	close_button.pressed.connect(_close_panel)
	box.add_child(close_button)

	option_panel = Panel.new()
	option_panel.visible = false
	option_panel.position = Vector2(16, 122)
	option_panel.size = Vector2(258, 230)
	panel.add_child(option_panel)

	option_list = VBoxContainer.new()
	option_list.position = Vector2(10, 10)
	option_list.size = Vector2(238, 210)
	option_panel.add_child(option_list)

	confirm_button = Button.new()
	confirm_button.text = "PLACE BUILDING"
	confirm_button.custom_minimum_size = Vector2(115, 48)
	confirm_button.pressed.connect(_confirm_build)
	confirm_button.visible = false
	panel.add_child(confirm_button)
	confirm_button.position = Vector2(26, 360)

	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.custom_minimum_size = Vector2(105, 48)
	cancel_button.pressed.connect(_cancel_build)
	cancel_button.visible = false
	panel.add_child(cancel_button)
	cancel_button.position = Vector2(158, 360)

	workshop_button = Button.new()
	var open_button := workshop_button
	open_button.name = "WorkshopButton"
	open_button.text = "WORKSHOP"
	open_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	open_button.position = Vector2(-190, -185)
	open_button.size = Vector2(160, 58)
	open_button.pressed.connect(_toggle_panel)
	add_child(open_button)

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		mode = ""
		selected_id = ""
		option_panel.visible = false
		confirm_button.visible = false
		cancel_button.visible = false
		set_process(false)
		if building:
			building.cancel_placement()
		status.text = "Choose an action."

func _close_panel() -> void:
	if building:
		building.cancel_placement()
	panel.visible = false
	mode = ""
	set_process(false)

func _show_crafting() -> void:
	mode = "craft"
	option_panel.visible = true
	confirm_button.visible = false
	cancel_button.visible = false
	set_process(false)
	_clear_options()
	status.text = "Select an item to craft."
	for recipe_id in VeyraCraftingCatalog.all_recipe_ids():
		var recipe := VeyraCraftingCatalog.get_recipe(recipe_id)
		var button := Button.new()
		var cost: Dictionary = recipe.get("cost", {})
		button.text = "%s  •  %s%s" % [recipe.get("name", recipe_id), _format_cost(cost), "  ✓" if _has_cost(cost) else ""]
		button.custom_minimum_size = Vector2(238, 48)
		button.pressed.connect(_craft.bind(recipe_id))
		option_list.add_child(button)

func _craft(recipe_id: String) -> void:
	if not crafting or not inventory:
		return
	if crafting.craft(recipe_id, inventory):
		var recipe := VeyraCraftingCatalog.get_recipe(recipe_id)
		status.text = "Crafted %s." % recipe.get("name", recipe_id)
	else:
		status.text = "Need materials or inventory space."

func _show_building() -> void:
	mode = "build"
	option_panel.visible = true
	confirm_button.visible = false
	cancel_button.visible = true
	set_process(true)
	_clear_options()
	status.text = "Select a building."
	for building_id in VeyraBuildingCatalog.all_building_ids():
		var definition := VeyraBuildingCatalog.get_building(building_id)
		var button := Button.new()
		var cost: Dictionary = definition.get("cost", {})
		button.text = "%s  •  %s%s" % [definition.get("name", building_id), _format_cost(cost), "  ✓" if _has_cost(cost) else ""]
		button.custom_minimum_size = Vector2(238, 48)
		button.pressed.connect(_select_building.bind(building_id))
		option_list.add_child(button)

func _select_building(building_id: String) -> void:
	selected_id = building_id
	if building and building.select_building(building_id):
		status.text = "Move the camera to position the preview."
		confirm_button.visible = true
		confirm_button.disabled = false

func _confirm_build() -> void:
	if building and building.confirm_build(player, inventory):
		status.text = "Building placed."
		selected_id = ""
		confirm_button.visible = false
		_cancel_build()
	else:
		status.text = "Invalid location or missing materials."

func _cancel_build() -> void:
	if building:
		building.cancel_placement()
	mode = ""
	set_process(false)
	option_panel.visible = false
	confirm_button.visible = false
	cancel_button.visible = false
	status.text = "Choose an action."

func _update_build_status() -> void:
	if not building:
		return
	if building.placement_valid:
		status.text = "Location valid — tap PLACE BUILDING."
	else:
		status.text = "Invalid location or missing materials."

func _clear_options() -> void:
	for child in option_list.get_children():
		child.queue_free()

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost.keys():
		parts.append("%s x%d" % [key, int(cost[key])])
	return ", ".join(parts)
