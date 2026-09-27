extends Control

@onready var status_label: Label = $Center/Panel/Status
var graphics_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Center/Panel/EnterButton.pressed.connect(_enter_world)
	$Center/Panel/SettingsButton.pressed.connect(_show_settings)
	$Center/Panel/ExitButton.pressed.connect(_exit_game)
	$Center/Panel/SettingsPanel/BackButton.pressed.connect(_hide_settings)
	_$Center_unused = null
	$Center/Panel/SettingsPanel.visible = false
	_build_graphics_controls()
	var save_exists := not SaveManager.load_world().is_empty() if SaveManager else false
	$Center/Panel/EnterButton.text = "CONTINUE" if save_exists else "ENTER VEYRA"

func _build_graphics_controls() -> void:
	var panel := $Center/Panel/SettingsPanel
	graphics_label = panel.get_node_or_null("GraphicsLabel") as Label
	if not graphics_label:
		graphics_label = Label.new()
		graphics_label.name = "GraphicsLabel"
		graphics_label.position = Vector2(20, 105)
		graphics_label.size = Vector2(310, 32)
		graphics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(graphics_label)
	for profile in [GraphicsSettings.PROFILE_PERFORMANCE, GraphicsSettings.PROFILE_BALANCED, GraphicsSettings.PROFILE_QUALITY]:
		var button := Button.new()
		button.text = profile
		button.custom_minimum_size = Vector2(96, 42)
		button.pressed.connect(_set_graphics.bind(profile))
		panel.add_child(button)
		button.position = Vector2(18 + 106 * [GraphicsSettings.PROFILE_PERFORMANCE, GraphicsSettings.PROFILE_BALANCED, GraphicsSettings.PROFILE_QUALITY].find(profile), 145)
	_update_graphics_label()

func _set_graphics(profile: String) -> void:
	GraphicsSettings.set_profile(profile)
	_update_graphics_label()

func _update_graphics_label() -> void:
	if graphics_label:
		graphics_label.text = "GRAPHICS  •  %s" % GraphicsSettings.get_display_name()

func _enter_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _show_settings() -> void:
	$Center/Panel/EnterButton.visible = false
	$Center/Panel/SettingsButton.visible = false
	$Center/Panel/ExitButton.visible = false
	$Center/Panel/SettingsPanel.visible = true
	status_label.text = "SETTINGS"

func _hide_settings() -> void:
	$Center/Panel/SettingsPanel.visible = false
	$Center/Panel/EnterButton.visible = true
	$Center/Panel/SettingsButton.visible = true
	$Center/Panel/ExitButton.visible = true
	status_label.text = "A LIVING WORLD • ONE SHARED REALITY"

func _exit_game() -> void:
	get_tree().quit()
