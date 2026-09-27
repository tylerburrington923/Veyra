extends StaticBody3D
class_name VeyraEchoStone

## Echo-Stone is a low-cost anomaly/resource hybrid.
## A Stone Pick extracts ordinary resonance. Vitreous Lux acts as a catalyst:
## it accelerates attunement and can trigger a resonance release.

@export var hardness := 3.0
@export var memory_decay_per_second := 0.035
@export var release_threshold := 6.0
@export var base_yield := 1
@export var attuned_yield := 2

var stored_energy := 0.0
var thermal_state := 0.0
var structural_state := 0.0
var resonance_state := 0.0
var activated := false
var interaction_cooldown := 0.0
var _visual_accumulator := 0.0

@onready var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D

func _ready() -> void:
	add_to_group("echo_stone")
	add_to_group("interactable")
	var terrain := get_parent().get_node_or_null("WorldGenerator")
	if terrain and terrain.has_method("get_height_at_world"):
		global_position.y = terrain.get_height_at_world(global_position.x, global_position.z) + 0.9
	_refresh_visual()
	set_process(false)

func _process(delta: float) -> void:
	interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
	stored_energy = maxf(0.0, stored_energy - memory_decay_per_second * delta)
	thermal_state = move_toward(thermal_state, 0.0, delta * 0.12)
	resonance_state = move_toward(resonance_state, 0.0, delta * 0.2)
	_visual_accumulator += delta

	if activated and stored_energy <= release_threshold * 0.35:
		activated = false
		_refresh_visual()
	elif _visual_accumulator >= 0.12:
		_visual_accumulator = 0.0
		_refresh_visual()
	if stored_energy <= 0.0 and thermal_state <= 0.0 and resonance_state <= 0.0 and interaction_cooldown <= 0.0 and not activated:
		set_process(false)

func can_interact(player: Node) -> bool:
	if interaction_cooldown > 0.0 or not player or not player.has_method("get_tool_id"):
		return false
	return player.get_tool_id() == VeyraItemCatalog.TOOL_IDS[1]

func get_interaction_requirement(player: Node) -> String:
	return "" if can_interact(player) else "Stone Pick"

func get_interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("local_player")
	return _action_text_for(player)

func _action_text_for(player: Node) -> String:
	if player and player.has_method("get_inventory"):
		var inventory := player.get_inventory()
		if inventory and inventory.has_method("has_resource") and inventory.has_resource("Vitreous Lux", 1):
			return "ATTUNE ECHO-STONE"
	return "MINE ECHO-STONE"

func interact(player_override: Node = null) -> void:
	if interaction_cooldown > 0.0:
		return
	var player: Node = player_override if player_override else get_tree().get_first_node_in_group("local_player")
	if not can_interact(player):
		return

	var inventory: Node = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return

	var attuned := inventory.has_resource("Vitreous Lux", 1)
	var yield_amount := attuned_yield if attuned else base_yield
	var accepted := int(inventory.add_resource("Echo-Stone", yield_amount))
	if accepted <= 0:
		return

	if attuned:
		inventory.remove_resource("Vitreous Lux", 1)
		stored_energy = minf(release_threshold * 1.5, stored_energy + 3.0)
		resonance_state = clampf(resonance_state + 0.35, 0.0, 1.0)
	else:
		stored_energy = minf(release_threshold * 1.5, stored_energy + 1.0)
		resonance_state = clampf(resonance_state + 0.12, 0.0, 1.0)

	var tool_cost := VeyraItemCatalog.durability_cost(player.get_tool_id(), "Echo-Stone")
	if tool_cost > 0.0 and player.has_method("use_tool") and not player.use_tool(tool_cost):
		inventory.remove_resource("Echo-Stone", accepted)
		return

	interaction_cooldown = 0.24
	set_process(true)
	if player.has_method("add_resonance"):
		player.add_resonance(0.8 if attuned else 0.3)

	if stored_energy >= release_threshold:
		_release(player)

	_refresh_visual()

func resonate(strength: float) -> void:
	# Kept as a lightweight compatibility path for the interaction system.
	var force := maxf(0.0, strength)
	stored_energy = minf(release_threshold * 1.5, stored_energy + force / maxf(hardness, 0.1))
	resonance_state = clampf(resonance_state + force * 0.08, 0.0, 1.0)
	set_process(true)
	_refresh_visual()

func heat(amount: float) -> void:
	thermal_state = clampf(thermal_state + amount, 0.0, 1.0)
	stored_energy = minf(release_threshold * 1.5, stored_energy + amount * 0.5)
	set_process(true)
	_refresh_visual()

func get_material_state() -> Dictionary:
	return {
		"hardness": hardness,
		"stored_energy": stored_energy,
		"thermal_state": thermal_state,
		"structural_state": structural_state,
		"resonance_state": resonance_state,
		"activated": activated
	}

func get_interaction_point() -> Vector3:
	return global_position + Vector3.UP * 0.75

func _release(player: Node) -> void:
	activated = true
	stored_energy *= 0.22
	structural_state = clampf(stored_energy / release_threshold, 0.0, 1.0)

	# A completed resonance cycle returns a small amount of Lux: the rare
	# resource is both a catalyst and a renewable reward for understanding the
	# anomaly, rather than a disposable crafting ingredient.
	var inventory: Node = player.get_inventory() if player and player.has_method("get_inventory") else null
	if inventory:
		inventory.add_resource("Vitreous Lux", 1)
	if player and player.has_method("add_resonance"):
		player.add_resonance(2.5)

	_refresh_visual()

func _refresh_visual() -> void:
	if not mesh:
		return
	var material := mesh.get_active_material(0)
	if material is StandardMaterial3D:
		var m := material as StandardMaterial3D
		var glow := clampf(resonance_state * 1.35 + thermal_state * 0.35 + (0.42 if activated else 0.0), 0.0, 1.25)
		m.emission_enabled = glow > 0.04
		m.emission = Color(0.16, 0.06, 0.28, 1) * glow
		m.emission_energy_multiplier = 0.55 + glow * 1.55
