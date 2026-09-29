extends CanvasLayer
class_name VeyraMerchantUI

var player: Node
var panel: Panel
var body: VBoxContainer
var status: Label
var manager: VeyraMerchantManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 300
	manager = get_node_or_null("/root/MerchantManager") as VeyraMerchantManager
	_build()
	visible = false

func open(p_player: Node) -> void:
	player = p_player
	visible = true
	_refresh()

func _build() -> void:
	panel = Panel.new()
	panel.add_to_group("camera_blocking_ui")
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.055, 0.985)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.65, 0.68, 0.8)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(520, 620)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	panel.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

func _refresh() -> void:
	for child in body.get_children():
		child.queue_free()
	if not player or not manager:
		return
	var title := Label.new()
	title.text = "MERCHANT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	body.add_child(title)
	status = Label.new()
	status.text = "Coins: %d" % player.get_inventory().get_coins()
	status.add_theme_font_size_override("font_size", 15)
	body.add_child(status)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func(): visible = false)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(close)

	var buy_label := Label.new()
	buy_label.text = "BUY"
	buy_label.add_theme_font_size_override("font_size", 17)
	body.add_child(buy_label)
	for item_id in manager.get_buy_offers().keys():
		var offer: Dictionary = manager.get_buy_offers()[item_id]
		var button := Button.new()
		button.text = "%s  •  %d coins" % [_display_name(str(item_id)), int(offer["price"])]
		button.disabled = player.get_inventory().get_coins() < int(offer["price"])
		button.pressed.connect(_buy.bind(str(item_id)))
		body.add_child(button)

	var sell_label := Label.new()
	sell_label.text = "SELL WHAT YOU CARRY"
	sell_label.add_theme_font_size_override("font_size", 17)
	body.add_child(sell_label)
	for item_id in _sellable_ids():
		var button := Button.new()
		button.text = "%s  •  %d coin each" % [_display_name(item_id), int(manager.get_sell_offers()[item_id])]
		button.pressed.connect(_sell.bind(item_id))
		body.add_child(button)

func _buy(item_id: String) -> void:
	status.text = "Purchase request sent." if manager.request_buy(player, item_id) else "Purchase unavailable."
	_refresh()

func _sell(item_id: String) -> void:
	status.text = "Sale request sent." if manager.request_sell(player, item_id, 1) else "Nothing to sell."
	_refresh()

func _sellable_ids() -> Array[String]:
	var result: Array[String] = []
	var inventory: VeyraInventory = player.get_inventory()
	for item_id in inventory.get_resource_types():
		if manager.get_sell_offers().has(item_id):
			result.append(item_id)
	for item_id in inventory.get_item_types():
		if manager.get_sell_offers().has(item_id):
			result.append(item_id)
	result.sort()
	return result

func _display_name(id: String) -> String:
	return VeyraItemCatalog.display_name(id) if VeyraItemCatalog.is_valid(id) else VeyraResourceCatalog.display_name(id)
