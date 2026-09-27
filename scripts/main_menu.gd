extends Control

@onready var status_label: Label = $Center/Panel/Status

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Center/Panel/EnterButton.pressed.connect(_enter_world)
	$Center/Panel/SettingsButton.pressed.connect(_show_settings)
	$Center/Panel/ExitButton.pressed.connect(_exit_game)
	$Center/Panel/SettingsPanel/BackButton.pressed.connect(_hide_settings)
	$Center/Panel/SettingsPanel.visible = false
	var save_exists := not SaveManager.load_world().is_empty() if SaveManager else false
	$Center/Panel/EnterButton.text = "CONTINUE" if save_exists else "ENTER VEYRA"

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
