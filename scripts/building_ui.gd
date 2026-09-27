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

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("building_ui")
	_build_base()
	visible = false

func open_campfire(building: Node, player: Node) -> void:
	_open(building, player, "CAMPFIRE")
	_add_text("Add wood to keep the fire burning.")
	_add_action("ADD WOOD", _campfire_action)

func open_townhall(building: Node, player: Node) -> void:
	_open(building, player, "TOWN HALL")
	_add_text("Settlement control. Build from here once the Town Hall exists.")
	_add_text("Select a structure below. The world will close behind this menu and placement begins after selection.")
	for building_id in VeyraBuildingCatalog.all_building_ids():
		var definition := VeyraBuildingCatalog.get_building(building_id)
		_add_build_option(building_id, definition)

func open_blacksmith(building: Node, player: Node) -> void:
	_open(building, player, "BLACKSMITH")
	_add_text("Refine raw Metal into Refined Metal, then forge durable tools.")
	_add_action("REFINE 2 METAL → 1 REFINED", _refine_action)
	_add_action("FORGE STONE AXE", _forge_axe)
	_add_action("FORGE STONE PICK", _forge_pick)

func close_ui() -> void:
	visible = false
	_building = null
	_player = null
	_mode = ""

func _process(_delta: float) -> void:
	if not visible:
		return
	if _mode == "campfire":
		_refresh_campfire()
	elif _mode == "townhall":
		_refresh_townhall()
	elif _mode == "blacksmith":
		_refresh_blacksmith()

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
	_mode = title_text.to_lower().replace(" ", "_")
	_clear_body()
	visible = true
	get_viewport().set_input_as_handled()

func _build_base() -> void:
	panel = Panel.new()
	panel.name = "BuildingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	title_label.position = Vector2(16, 12)
	title_label.size = Vector2(width - 32, 38)
	body_scroll.position = Vector2(16, 58)
	body_scroll.size = Vector2(width - 32, height - 122)
	close_button.position = Vector2(16, height - 56)
	close_button.size = Vector2(width - 32, 44)

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
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.add_child(label)

func _add_action(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_style_button(button)
	body_box.add_child(button)

func _add_build_option(id: String, definition: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.text = str(definition.get("name", id))
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_begin_build.bind(id))
	_style_button(button)
	row.add_child(button)
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

func _campfire_action() -> void:
	if _building and _building.has_method("add_campfire_fuel"):
		_building.add_campfire_fuel(_player, 1)

func _refine_action() -> void:
	if _building and _building.has_method("blacksmith_refine"):
		_building.blacksmith_refine(_player)
		_refresh_blacksmith()

func _forge_axe() -> void:
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I01_STONE_AXE")
		_refresh_blacksmith()

func _forge_pick() -> void:
	if _building and _building.has_method("blacksmith_forge"):
		_building.blacksmith_forge(_player, "I02_STONE_PICK")
		_refresh_blacksmith()

func _refresh_campfire() -> void:
	if not _building:
		return
	var heat := float(_building.get_campfire_heat()) if _building.has_method("get_campfire_heat") else 0.0
	_add_or_update_status("Heat remaining: %.0f sec" % heat)

func _refresh_townhall() -> void:
	pass

func _refresh_blacksmith() -> void:
	pass

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

func _style_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.16, 0.18, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.65, 0.68, 0.62)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", style)
