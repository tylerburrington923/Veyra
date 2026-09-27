extends CanvasLayer
class_name VeyraPauseMenu

var panel: Panel
var title: Label
var status: Label
var resume_button: Button
var settings_button: Button
var multiplayer_button: Button
var close_settings_button: Button
var settings_panel: Panel
var _paused: bool = false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	var menu_button := Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "MENU"
	menu_button.position = Vector2(1120, 24)
	menu_button.size = Vector2(120, 48)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.add_to_group("camera_blocking_ui")
	menu_button.pressed.connect(_toggle)
	add_child(menu_button)

	panel = Panel.new()
	panel.name = "PausePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(390, 360)
	panel.position -= panel.size * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	title = Label.new()
	title.text = "VEYRA"
	title.position = Vector2(20, 18)
	title.size = Vector2(350, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	status = Label.new()
	status.text = "GAME PAUSED"
	status.position = Vector2(25, 64)
	status.size = Vector2(340, 32)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status)

	resume_button = _make_button("RESUME", Vector2(35, 112), Vector2(320, 52))
	resume_button.pressed.connect(_resume)
	settings_button = _make_button("SETTINGS", Vector2(35, 176), Vector2(320, 52))
	settings_button.pressed.connect(_show_settings)
	multiplayer_button = _make_button("MULTIPLAYER", Vector2(35, 240), Vector2(320, 52))
	multiplayer_button.pressed.connect(_show_multiplayer)
	panel.add_child(resume_button)
	panel.add_child(settings_button)
	panel.add_child(multiplayer_button)

	settings_panel = Panel.new()
	settings_panel.position = Vector2(25, 105)
	settings_panel.size = Vector2(340, 210)
	settings_panel.visible = false
	panel.add_child(settings_panel)

	var settings_label := Label.new()
	settings_label.text = "SETTINGS\\n\\nGraphics: Compatibility\\nWorld simulation remains deterministic.\\n\\nAudio and detailed graphics controls will be added without changing gameplay authority."
	settings_label.position = Vector2(18, 16)
	settings_label.size = Vector2(304, 145)
	settings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_panel.add_child(settings_label)

	close_settings_button = _make_button("BACK", Vector2(95, 158), Vector2(150, 38))
	close_settings_button.pressed.connect(_hide_settings)
	settings_panel.add_child(close_settings_button)

func _make_button(text_value: String, pos: Vector2, size_value: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 18)
	button.add_to_group("camera_blocking_ui")
	return button

func _toggle() -> void:
	if visible:
		_resume()
	else:
		_open()

func _open() -> void:
	visible = true
	settings_panel.visible = false
	_paused = not _network_session_active()
	if _paused:
		get_tree().paused = true
	status.text = "GAME PAUSED"
	else:
		status.text = "MULTIPLAYER MENU"
	resume_button.text = "RESUME"
	_update_multiplayer_button()

func _resume() -> void:
	settings_panel.visible = false
	visible = false
	if _paused:
		get_tree().paused = false
	_paused = false

func _show_settings() -> void:
	settings_panel.visible = true
	resume_button.visible = false
	settings_button.visible = false
	multiplayer_button.visible = false
	status.text = "SETTINGS"

func _hide_settings() -> void:
	settings_panel.visible = false
	resume_button.visible = true
	settings_button.visible = true
	multiplayer_button.visible = true
	status.text = "GAME PAUSED" if _paused else "MULTIPLAYER MENU"

func _show_multiplayer() -> void:
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.lobby_layer:
		network_manager.lobby_layer.visible = true
		network_manager.lobby_layer.get_node("MultiplayerPanel").position = Vector2(445, 170)
	status.text = "MULTIPLAYER PANEL OPEN"
	_update_multiplayer_button()

func _update_multiplayer_button() -> void:
	multiplayer_button.text = "MULTIPLAYER" if not _network_session_active() else "MULTIPLAYER • ACTIVE"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _paused:
		get_tree().paused = false
		_paused = false

func _network_session_active() -> bool:
	var network_manager = get_node_or_null("/root/NetworkManager")
	return network_manager != null and bool(network_manager.session_active)
