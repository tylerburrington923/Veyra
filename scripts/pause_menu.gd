extends CanvasLayer

var panel
var status
var resume_button
var settings_button
var multiplayer_button
var main_menu_button
var settings_panel
var paused_by_menu := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	var menu_button := Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "MENU"
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.position = Vector2(-122, 18)
	menu_button.size = Vector2(104, 44)
	menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_button.add_to_group("camera_blocking_ui")
	menu_button.pressed.connect(_toggle)
	add_child(menu_button)

	panel = Panel.new()
	panel.name = "PausePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(360, 350)
	panel.custom_minimum_size = Vector2(320, 300)
	panel.position = -panel.size * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var title := Label.new()
	title.text = "VEYRA"
	title.position = Vector2(20, 18)
	title.size = Vector2(320, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	status = Label.new()
	status.text = "GAME PAUSED"
	status.position = Vector2(25, 64)
	status.size = Vector2(310, 32)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status)

	resume_button = _make_button("RESUME", Vector2(25, 112), Vector2(310, 50))
	resume_button.pressed.connect(_resume)
	settings_button = _make_button("SETTINGS", Vector2(25, 172), Vector2(310, 50))
	settings_button.pressed.connect(_show_settings)
	multiplayer_button = _make_button("MULTIPLAYER", Vector2(25, 232), Vector2(150, 50))
	multiplayer_button.pressed.connect(_show_multiplayer)
	main_menu_button = _make_button("MAIN MENU", Vector2(185, 232), Vector2(150, 50))
	main_menu_button.pressed.connect(_return_to_main_menu)
	panel.add_child(resume_button)
	panel.add_child(settings_button)
	panel.add_child(multiplayer_button)
	panel.add_child(main_menu_button)

	settings_panel = Panel.new()
	settings_panel.position = Vector2(18, 98)
	settings_panel.size = Vector2(324, 235)
	settings_panel.visible = false
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(settings_panel)

	var settings_label := Label.new()
	settings_label.text = "SETTINGS\n\nGraphics: Compatibility\nWorld simulation remains deterministic."
	settings_label.position = Vector2(16, 12)
	settings_label.size = Vector2(292, 82)
	settings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_panel.add_child(settings_label)

	var profile_x := 10
	for profile in [GraphicsSettings.PROFILE_PERFORMANCE, GraphicsSettings.PROFILE_BALANCED, GraphicsSettings.PROFILE_QUALITY]:
		var profile_button := _make_button(profile, Vector2(profile_x, 100), Vector2(96, 38))
		profile_button.pressed.connect(_set_graphics_profile.bind(profile))
		settings_panel.add_child(profile_button)
		profile_x += 104

	var back_button := _make_button("BACK", Vector2(87, 174), Vector2(150, 38))
	back_button.pressed.connect(_hide_settings)
	settings_panel.add_child(back_button)

func _set_graphics_profile(profile: String) -> void:
	GraphicsSettings.set_profile(profile)
	status.text = "GRAPHICS: %s" % GraphicsSettings.get_display_name()

func _make_button(text_value: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
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
	paused_by_menu = not _network_session_active()
	if paused_by_menu:
		get_tree().paused = true
	status.text = "GAME PAUSED" if paused_by_menu else "MULTIPLAYER MENU"
	resume_button.text = "RESUME"
	_update_multiplayer_button()

func _resume() -> void:
	settings_panel.visible = false
	visible = false
	if paused_by_menu:
		get_tree().paused = false
	paused_by_menu = false

func _show_settings() -> void:
	settings_panel.visible = true
	resume_button.visible = false
	settings_button.visible = false
	multiplayer_button.visible = false
	main_menu_button.visible = false
	status.text = "SETTINGS"

func _hide_settings() -> void:
	settings_panel.visible = false
	resume_button.visible = true
	settings_button.visible = true
	multiplayer_button.visible = true
	main_menu_button.visible = true
	status.text = "GAME PAUSED" if paused_by_menu else "MULTIPLAYER MENU"

func _show_multiplayer() -> void:
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		var lobby = network_manager.get("lobby_layer")
		if lobby and is_instance_valid(lobby):
			lobby.visible = true
			var lobby_panel = lobby.get_node_or_null("MultiplayerPanel")
			if lobby_panel:
				lobby_panel.position = Vector2(445, 170)
	status.text = "MULTIPLAYER PANEL OPEN"
	_update_multiplayer_button()

func _update_multiplayer_button() -> void:
	multiplayer_button.text = "MULTIPLAYER" if not _network_session_active() else "MULTIPLAYER - ACTIVE"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and paused_by_menu:
		get_tree().paused = false
		paused_by_menu = false

func _network_session_active() -> bool:
	var network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		return false
	return bool(network_manager.get("session_active"))

func _return_to_main_menu() -> void:
	if paused_by_menu:
		get_tree().paused = false
	paused_by_menu = false
	var world := get_tree().current_scene
	var manager := get_node_or_null("/root/GameManager")
	if manager and world:
		manager.save_current_game(world)
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager and bool(network_manager.get("session_active")):
		network_manager.leave_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
