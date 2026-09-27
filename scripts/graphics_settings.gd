extends Node
class_name VeyraGraphicsSettings

const PROFILE_BALANCED := "BALANCED"
const PROFILE_PERFORMANCE := "PERFORMANCE"
const PROFILE_QUALITY := "QUALITY"
const CONFIG_PATH := "user://veyra_graphics.cfg"

var profile: String = PROFILE_BALANCED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = _load_profile()
	call_deferred("_apply_current_scene")

func _apply_current_scene() -> void:
	var world := get_tree().current_scene
	if world and world.has_method("apply_graphics_profile"):
		world.apply_graphics_profile(profile)

func set_profile(next_profile: String) -> void:
	if next_profile not in [PROFILE_PERFORMANCE, PROFILE_BALANCED, PROFILE_QUALITY]:
		next_profile = PROFILE_BALANCED
	profile = next_profile
	_save_profile()
	_apply_current_scene()

func get_profile() -> String:
	return profile

func get_camera_far() -> float:
	match profile:
		PROFILE_PERFORMANCE:
			return 90.0
		PROFILE_QUALITY:
			return 140.0
		_:
			return 115.0

func get_foliage_distance() -> float:
	match profile:
		PROFILE_PERFORMANCE:
			return 58.0
		PROFILE_QUALITY:
			return 105.0
		_:
			return 82.0

func get_detail_distance() -> float:
	match profile:
		PROFILE_PERFORMANCE:
			return 52.0
		PROFILE_QUALITY:
			return 95.0
		_:
			return 72.0

func get_fog_density() -> float:
	match profile:
		PROFILE_PERFORMANCE:
			return 0.008
		PROFILE_QUALITY:
			return 0.0045
		_:
			return 0.006

func get_display_name() -> String:
	match profile:
		PROFILE_PERFORMANCE:
			return "PERFORMANCE"
		PROFILE_QUALITY:
			return "QUALITY"
		_:
			return "BALANCED"

func _load_profile() -> String:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return PROFILE_BALANCED if OS.has_feature("mobile") else PROFILE_QUALITY
	var saved := str(config.get_value("graphics", "profile", PROFILE_BALANCED))
	return saved if saved in [PROFILE_PERFORMANCE, PROFILE_BALANCED, PROFILE_QUALITY] else PROFILE_BALANCED

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "profile", profile)
	config.save(CONFIG_PATH)
