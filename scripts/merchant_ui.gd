extends CanvasLayer
class_name VeyraMerchantUI

var player: Node
var panel: Panel
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var close_button: Button
var manager: VeyraMerchantManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 300
	manager = get_node_or_null("/root/MerchantManager") as VeyraMerchantManager
	add_to_group("modal_ui")
	_build()
	visible = false

func open(p_player: Node) -> void:
	player = p_player
	_layout_panel()
	visible = true
	_refresh()

func _layout_panel() -> void:
	if not panel:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	panel.size = Vector2(
		minf(520.0, maxf(240.0, viewport_size.x - 24.0)),
		minf(620.0, maxf(320.0, viewport_size.y - 32.0))
	)
	panel.position = (viewport_size - panel.size) * 0.5
	if close_button:
		close_button.size = Vector2(panel.size.x - 32.0, 36.0)
	if scroll:
		scroll.offset_left = 16.0
		scroll.offset_top = 56.0
		scroll.offset_right = -16.0
		scroll.offset_bottom = -16.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and panel:
		_layout_panel()

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
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	scroll.offset_top = 56.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	close_button = Button.new()
	close_button.name = "CloseMerchant"
	close_button.text = "CLOSE"
	close_button.position = Vector2(16.0, 12.0)
	close_button.size = Vector2(panel.size.x - 32.0, 36.0)
	close_button.add_to_group("camera_blocking_ui")
	close_button.pressed.connect(func(): visible = false)
	panel.add_child(close_button)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

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
	var buy_label := Label.new()
	buy_label.text = "BUY"
	buy_label.add_theme_font_size_override("font_size", 17)
	body.add_child(buy_label)
	for item_id in manager.get_buy_offers().keys():
		var offer: Dictionary = manager.get_buy_offers()[item_id]
		var button := Button.new()
		button.text = "%s  ×%d  •  %d coins" % [_display_name(str(item_id)), int(offer.get("amount", 1)), int(offer["price"])]
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
	var ok := manager.request_buy(player, item_id)
	_refresh()
	status.text = "Purchase request sent." if ok else "Purchase unavailable."

func _sell(item_id: String) -> void:
	var ok := manager.request_sell(player, item_id, 1)
	_refresh()
	status.text = "Sale request sent." if ok else "Nothing to sell."

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


func is_modal_open() -> bool:
	return visible

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
