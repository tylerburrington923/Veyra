extends CanvasLayer
class_name VeyraBuildingUI

var panel: Panel
var title_label: Label
var body_label: Label
var action_button: Button
var close_button: Button
var _building: Node
var _player: Node

func _ready() -> void:
	layer = 80
	add_to_group("building_ui")
	_build_base()
	visible = false

func open_campfire(building: Node, player: Node) -> void:
	_building = building
	_player = player
	title_label.text = "CAMPFIRE"
	action_button.text = "ADD WOOD"
	_refresh_campfire()
	visible = true

func open_townhall(building: Node, player: Node) -> void:
	_building = building
	_player = player
	title_label.text = "TOWN HALL"
	action_button.text = "DEPOSIT 10"
	_refresh_townhall()
	visible = true

func close_ui() -> void:
	visible = false
	_building = null
	_player = null

func _process(_delta: float) -> void:
	if not visible or not _building:
		return
	if title_label.text == "CAMPFIRE":
		_refresh_campfire()
	else:
		_refresh_townhall()

func _on_action_pressed() -> void:
	if not _building:
		return
	if title_label.text == "CAMPFIRE":
		if _building.has_method("add_campfire_fuel"):
			_building.add_campfire_fuel(_player, 1)
			_refresh_campfire()
	else:
		if _building.has_method("deposit_civic_materials"):
			_building.deposit_civic_materials(_player, 10)
			_refresh_townhall()

func _build_base() -> void:
	panel = Panel.new()
	panel.name = "BuildingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.06, 0.98)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.24, 0.62, 0.66, 0.72)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.42, 0.82, 0.84, 1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.85, 1))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.custom_minimum_size = Vector2(0, 260)
	scroll.add_child(body_label)

	action_button = Button.new()
	action_button.add_theme_font_size_override("font_size", 16)
	action_button.pressed.connect(_on_action_pressed)
	_style_button(action_button)
	panel.add_child(action_button)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(close_ui)
	_style_button(close_button)
	panel.add_child(close_button)

	_layout_panel()

func _layout_panel() -> void:
	if not panel:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(440.0, maxf(280.0, viewport_size.x - 24.0))
	var height := minf(400.0, maxf(260.0, viewport_size.y - 24.0))
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - panel.size) * 0.5
	title_label.position = Vector2(16, 12)
	title_label.size = Vector2(width - 32.0, 38.0)
	var button_y := height - 62.0
	var gap := 12.0
	var button_width := (width - 56.0) * 0.5
	action_button.position = Vector2(20, button_y)
	action_button.size = Vector2(button_width, 44)
	close_button.position = Vector2(36.0 + button_width, button_y)
	close_button.size = Vector2(button_width, 44)
	var scroll := panel.get_node_or_null("BodyScroll") as ScrollContainer
	if scroll:
		scroll.position = Vector2(20, 58)
		scroll.size = Vector2(width - 40.0, maxf(120.0, button_y - 70.0))
		body_label.custom_minimum_size = Vector2(scroll.size.x - 8.0, 260.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_panel()
func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.16, 0.18, 0.98)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.30, 0.65, 0.68, 0.62)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.11, 0.24, 0.26, 1.0)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.16, 0.34, 0.36, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.05, 0.08, 0.09, 0.65)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

func _refresh_campfire() -> void:
	if not _building:
		return
	var heat := float(_building.get_campfire_heat()) if _building.has_method("get_campfire_heat") else 0.0
	var wood := 0
	if _player and _player.has_method("get_inventory"):
		var inventory: Node = _player.get_inventory()
		if inventory:
			wood = inventory.get_amount("Wood")
	body_label.text = "INPUT\n[  —  ]\n\nFUEL\n[  WOOD  ]   Backpack: %d\n\nOUTPUT\n[  HEAT  ]\n\nHeat remaining: %.0f sec\n\nEach Wood adds 30 seconds of campfire heat." % [wood, heat]
	action_button.disabled = wood <= 0

func _refresh_townhall() -> void:
	var settlement := get_node_or_null("/root/SettlementManager")
	if not settlement:
		body_label.text = "Settlement system unavailable."
		return
	var state: Dictionary = settlement.get_settlement_state()
	var stock: Dictionary = state.get("stock", {})
	var population := int(state.get("population", 0))
	var players: int = settlement.get_active_player_count() if settlement.has_method("get_active_player_count") else 0
	var villagers: int = settlement.get_active_villager_count() if settlement.has_method("get_active_villager_count") else 0
	var demand: int = settlement.get_water_demand() if settlement.has_method("get_water_demand") else 0
	var days: float = settlement.get_water_days_remaining() if settlement.has_method("get_water_days_remaining") else 0.0
	body_label.text = "%s\n\nPOPULATION   %d   •   PLAYERS %d   •   VILLAGERS %d\n\nWATER RESERVE   %d\nDAILY DEMAND   %d   •   COVERAGE %.1f DAYS\n\nFOOD   %d\nWOOD   %d\nSTONE   %d\n\nThe Well feeds the settlement reserve. Each player and villager consumes one Water per lunar cycle." % [
		str(state.get("name", "New Settlement")),
		population, players, villagers,
		int(stock.get("water", 0)), demand, float(days),
		int(stock.get("food", 0)), int(stock.get("wood", 0)), int(stock.get("stone", 0))
	]
	var can_deposit := false
	if _player and _player.has_method("get_inventory"):
		var inventory: Node = _player.get_inventory()
		can_deposit = inventory != null and (inventory.get_amount("Wood") > 0 or inventory.get_amount("Stone") > 0)
	action_button.disabled = not can_deposit
