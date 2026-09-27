extends CanvasLayer

var panel
var status
var resume_button
var settings_button
var multiplayer_button
var main_menu_button
var settings_panel
var menu_button: Button
var paused_by_menu := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Keep the CanvasLayer visible so the PAUSE button is always available.
	# Only the pause panel is hidden until the player opens it.
	visible = true
	panel.visible = false

func _build() -> void:
	menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "PAUSE"
	menu_button.position = Vector2(maxf(16.0, get_viewport().get_visible_rect().size.x - 116.0), 16.0)
	menu_button.size = Vector2(100, 42)
	menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_style_button(menu_button)
	menu_button.add_to_group("camera_blocking_ui")
	menu_button.pressed.connect(_toggle)
	add_child(menu_button)

	panel = Panel.new()
	panel.name = "PausePanel"
	panel.size = Vector2(370, 360)
	panel.custom_minimum_size = Vector2(320, 300)
	_center_control(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var title := Label.new()
	title.text = "VEYRA"
	title.position = Vector2(20, 18)
	title.size = Vector2(320, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.42, 0.82, 0.84, 1))
	panel.add_child(title)

	status = Label.new()
	status.text = "GAME PAUSED"
	status.position = Vector2(25, 62)
	status.size = Vector2(310, 32)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status)

	resume_button = _make_button("RESUME", Vector2(25, 108), Vector2(320, 50))
	resume_button.pressed.connect(_resume)
	settings_button = _make_button("SETTINGS", Vector2(25, 168), Vector2(320, 50))
	settings_button.pressed.connect(_show_settings)
	multiplayer_button = _make_button("MULTIPLAYER", Vector2(25, 228), Vector2(154, 50))
	multiplayer_button.pressed.connect(_show_multiplayer)
	main_menu_button = _make_button("MAIN MENU", Vector2(191, 228), Vector2(154, 50))
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

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.13, 0.16, 0.94)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.30, 0.58, 0.62, 0.55)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.11, 0.22, 0.25, 0.98)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.15, 0.31, 0.34, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.05, 0.08, 0.09, 0.65)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

func _make_button(text_value: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.name = text_value.replace(" ", "")
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	_style_button(button)
	button.add_to_group("camera_blocking_ui")
	return button

func _center_control(control: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	control.position = (viewport_size - control.size) * 0.5

func _toggle() -> void:
	if panel and panel.visible:
		_resume()
	else:
		_open()

func _open() -> void:
	visible = true
	panel.visible = true
	menu_button.visible = false
	settings_panel.visible = false
	paused_by_menu = not _network_session_active()
	if paused_by_menu:
		get_tree().paused = true
	status.text = "GAME PAUSED" if paused_by_menu else "MULTIPLAYER MENU"
	resume_button.text = "RESUME"
	_update_multiplayer_button()

func _resume() -> void:
	settings_panel.visible = false
	panel.visible = false
	visible = true
	menu_button.visible = true
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
	panel.visible = false
	menu_button.visible = false
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		var lobby = network_manager.get("lobby_layer")
		if lobby and is_instance_valid(lobby):
			lobby.visible = true
			var lobby_panel = lobby.get_node_or_null("MultiplayerPanel")
			if lobby_panel:
				var viewport_size := get_viewport().get_visible_rect().size
				lobby_panel.position = (viewport_size - lobby_panel.size) * 0.5
	status.text = "MULTIPLAYER PANEL OPEN"
	_update_multiplayer_button()

func show_pause_panel() -> void:
	_open()

func close_all_overlays() -> void:
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.has_method("close_lobby_ui"):
		network_manager.close_lobby_ui()
	var building_ui := get_tree().get_first_node_in_group("building_ui")
	if building_ui and building_ui.has_method("close_ui"):
		building_ui.close_ui()
	_resume()

func _update_multiplayer_button() -> void:
	multiplayer_button.text = "MULTIPLAYER" if not _network_session_active() else "MULTIPLAYER - ACTIVE"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		var menu_button := get_node_or_null("MenuButton") as Control
		if menu_button:
			menu_button.position = Vector2(maxf(16.0, get_viewport().get_visible_rect().size.x - menu_button.size.x - 16.0), 16.0)
		if panel:
			_center_control(panel)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and paused_by_menu:
		get_tree().paused = false
		paused_by_menu = false

func _network_session_active() -> bool:
	var network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		return false
	return bool(network_manager.get("session_active"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var network_manager = get_node_or_null("/root/NetworkManager")
		if network_manager and bool(network_manager.get("lobby_layer")) and network_manager.get("lobby_layer").visible:
			network_manager.close_lobby_ui()
			show_pause_panel()
			return
		if panel.visible:
			_resume()
		elif get_tree().get_first_node_in_group("building_ui"):
			close_all_overlays()

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
