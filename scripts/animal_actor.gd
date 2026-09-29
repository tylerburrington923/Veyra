class_name AnimalActor
extends StaticBody3D

var animal_manager: AnimalManager
var animal_id: String = ""
var interaction_cooldown: float = 0.0

func configure(manager: AnimalManager, p_animal_id: String) -> void:
	animal_manager = manager
	animal_id = p_animal_id

func _process(delta: float) -> void:
	interaction_cooldown = maxf(0.0, interaction_cooldown - delta)

func can_interact(player: Node = null) -> bool:
	if interaction_cooldown > 0.0 or not animal_manager:
		return false
	if player and player is Node3D and global_position.distance_to((player as Node3D).global_position) > 5.0:
		return false
	var state: AnimalState = animal_manager.states.get(animal_id)
	return state != null and state.alive

func get_interaction_text() -> String:
	return "ATTACK"

func get_interaction_point() -> Vector3:
	return global_position + Vector3.UP * 0.7

func get_interaction_feedback() -> String:
	if not animal_manager:
		return "WILDLIFE"
	var state: AnimalState = animal_manager.states.get(animal_id)
	var definition: AnimalDefinition = animal_manager.definitions.get(state.definition_id) if state else null
	if state and definition:
		return "%s • %d HP" % [definition.display_name, int(ceil(state.health))]
	return "WILDLIFE"

func interact(player: Node = null) -> void:
	if not can_interact(player):
		return
	interaction_cooldown = 0.45
	var damage := 8.0
	var tool_id := "T00_HANDS"
	if player and player.has_method("get_tool_id"):
		tool_id = str(player.get_tool_id())
		if tool_id != VeyraItemCatalog.HANDS_ID and player.has_method("can_use_tool") and not player.can_use_tool(1.0):
			return
		match tool_id:
			"I01_STONE_AXE", "I02_STONE_PICK":
				damage = 20.0
			"I04_METAL_AXE", "I05_METAL_PICK":
				damage = 30.0
			"I06_ECHO_AXE", "I07_ECHO_PICK":
				damage = 36.0
			"I08_HUNTER_KNIFE":
				damage = 24.0
			"I09_STONE_SPEAR":
				damage = 32.0
			"I10_METAL_SPEAR":
				damage = 46.0
	var result := animal_manager.damage_animal(animal_id, damage, player)
	if player and tool_id != VeyraItemCatalog.HANDS_ID and player.has_method("use_tool"):
		player.use_tool(1.0)
	var hotbar := player.get_node_or_null("Hotbar") if player else null
	if hotbar and hotbar.has_method("_show_toast"):
		hotbar._show_toast(result)
