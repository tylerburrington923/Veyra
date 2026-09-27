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
	layer = 30
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
	action_button.text = "CLOSE"
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
		close_ui()

func _build_base() -> void:
	panel = Panel.new()
	panel.name = "BuildingPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(430, 430)
	panel.position -= panel.size * 0.5
	add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(24, 18)
	title_label.size = Vector2(382, 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	panel.add_child(title_label)

	body_label = Label.new()
	body_label.position = Vector2(28, 76)
	body_label.size = Vector2(374, 250)
	body_label.add_theme_font_size_override("font_size", 19)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body_label)

	action_button = Button.new()
	action_button.position = Vector2(28, 340)
	action_button.size = Vector2(174, 54)
	action_button.add_theme_font_size_override("font_size", 18)
	action_button.pressed.connect(_on_action_pressed)
	panel.add_child(action_button)

	close_button = Button.new()
	close_button.position = Vector2(228, 340)
	close_button.size = Vector2(174, 54)
	close_button.text = "CLOSE"
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(close_ui)
	panel.add_child(close_button)

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
	var players := settlement.get_active_player_count() if settlement.has_method("get_active_player_count") else 0
	var villagers := settlement.get_active_villager_count() if settlement.has_method("get_active_villager_count") else 0
	var demand := settlement.get_water_demand() if settlement.has_method("get_water_demand") else 0
	var days := settlement.get_water_days_remaining() if settlement.has_method("get_water_days_remaining") else 0.0
	body_label.text = "SETTLEMENT: %s\n\nPOPULATION: %d\nPlayers: %d   Villagers: %d\n\nWATER RESERVE: %d\nDaily demand: %d\nCoverage: %.1f days\n\nFOOD: %d\nWOOD: %d\nSTONE: %d\n\nThe Well adds Water to the town reserve.\nWater is consumed for each player and villager each lunar cycle." % [
		str(state.get("name", "New Settlement")),
		population, players, villagers,
		int(stock.get("water", 0)), demand, float(days),
		int(stock.get("food", 0)), int(stock.get("wood", 0)), int(stock.get("stone", 0))
	]
	action_button.disabled = false
