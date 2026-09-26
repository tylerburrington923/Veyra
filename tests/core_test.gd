extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_inventory_round_trip()
	_test_crafting_transaction()
	_test_collision_contract()
	_test_tool_state_contract()
	_test_resource_collision_contract()
	_test_tool_catalog_contract()
	_test_first_person_viewmodel_contract()
	_test_first_person_presentation_contract()
	_test_resource_interaction_matrix()
	_test_npc_definition_data_layer()
	_test_npc_state_data_layer()
	_test_npc_state_validation_vs_sanitization()
	_test_npc_simulation_layer()
	_test_npc_simulation_definition_separation()
	_test_full_game_skeleton_contracts()
	if failures.is_empty():
		print("VEYRA CORE TESTS: PASS (15 suites)")
		quit(0)
	else:
		for failure in failures:
			push_error("VEYRA CORE TEST FAILURE: " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _crafting_manager() -> Node:
	return root.get_node("CraftingManager")

func _test_inventory_round_trip() -> void:
	var inventory := VeyraInventory.new()
	root.add_child(inventory)
	_check(inventory.add_resource("Wood", 7) == 7, "inventory should accept wood")
	_check(inventory.add_resource("Stone", 4) == 4, "inventory should accept stone")
	var snapshot := inventory.get_snapshot()
	var restored := VeyraInventory.new()
	root.add_child(restored)
	restored.load_snapshot(snapshot)
	_check(restored.get_amount("Wood") == 7, "wood snapshot mismatch")
	_check(restored.get_amount("Stone") == 4, "stone snapshot mismatch")
	_check(absf(restored.get_total_weight() - inventory.get_total_weight()) < 0.001, "weight snapshot mismatch")
	inventory.queue_free()
	restored.queue_free()

func _test_crafting_transaction() -> void:
	var inventory := VeyraInventory.new()
	root.add_child(inventory)
	inventory.add_resource("Wood", 3)
	inventory.add_resource("Stone", 2)
	_check(_crafting_manager().can_craft("I01_STONE_AXE", inventory), "axe should be craftable")
	_check(_crafting_manager().craft("I01_STONE_AXE", inventory), "axe craft should succeed")
	_check(inventory.has_item("I01_STONE_AXE"), "crafted axe missing")
	_check(inventory.get_amount("Wood") == 0, "axe craft should consume wood")
	_check(inventory.get_amount("Stone") == 0, "axe craft should consume stone")
	var before_wood := inventory.get_amount("Wood")
	var before_stone := inventory.get_amount("Stone")
	_check(not _crafting_manager().craft("I02_STONE_PICK", inventory), "pick should fail without materials")
	_check(inventory.get_amount("Wood") == before_wood, "failed craft changed wood")
	_check(inventory.get_amount("Stone") == before_stone, "failed craft changed stone")
	inventory.queue_free()

func _test_collision_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	_check((player.collision_mask & 1) != 0, "player must collide with terrain layer 1")
	_check((player.collision_mask & 2) != 0, "player must collide with solid world layer 2")
	_check((player.collision_mask & 4) == 0, "player must not physically collide with resource layer 4")
	var ray := player.get_node("Camera3D/InteractionRay") as RayCast3D
	_check((ray.collision_mask & 2) != 0 and (ray.collision_mask & 4) != 0, "interaction ray must see world and resources")
	player.queue_free()

func _test_tool_state_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.add_item("I01_STONE_AXE", 1)
	_check(player.set_tool("I01_STONE_AXE"), "axe should equip")
	_check(player.get_tool_id() == "I01_STONE_AXE", "equipped tool mismatch")
	var state: Dictionary = player.get_save_state()
	_check(state.get("tool_id", "") == "I01_STONE_AXE", "tool state not saved")
	_check(float(state.get("tool_durability", 0.0)) == 100.0, "initial durability mismatch")
	_check(player.use_tool(5.0), "tool should consume durability")
	_check(absf(float(player.get_save_state().get("tool_durability", 0.0)) - 95.0) < 0.001, "tool durability mismatch")
	var axe_slot := player.get_node_or_null("HUDInventory/ToolHotbar/AxeSlot") as Button
	_check(axe_slot != null, "mobile axe hotbar slot missing")
	_check(axe_slot.text.contains("AXE"), "axe hotbar slot label missing")
	_check(not axe_slot.disabled, "axe hotbar slot should be enabled after crafting/equipping")
	player.queue_free()


func _test_tool_catalog_contract() -> void:
	_check(VeyraItemCatalog.is_valid_tool(VeyraItemCatalog.HANDS_ID), "hands must be a valid tool")
	_check(VeyraItemCatalog.is_valid_tool("I01_STONE_AXE"), "axe must be a valid tool")
	_check(VeyraItemCatalog.is_valid_tool("I02_STONE_PICK"), "pick must be a valid tool")
	_check(not VeyraItemCatalog.is_valid_tool("NOT_A_TOOL"), "unknown tool must be rejected")
	_check(VeyraItemCatalog.is_tool_for_resource("I01_STONE_AXE", "Wood"), "axe must gather wood")
	_check(not VeyraItemCatalog.is_tool_for_resource(VeyraItemCatalog.HANDS_ID, "Wood"), "hands must not gather wood")
	_check(VeyraItemCatalog.is_tool_for_resource("I02_STONE_PICK", "Stone"), "pick must gather stone")
	_check(VeyraItemCatalog.is_tool_for_resource("I02_STONE_PICK", "Vitreous Lux"), "pick must gather Vitreous Lux")
	_check(VeyraItemCatalog.is_tool_for_resource("I02_STONE_PICK", "Echo-Stone"), "pick must gather Echo-Stone")

func _test_first_person_viewmodel_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)

	var camera := player.get_node_or_null("Camera3D") as Camera3D
	var viewmodel := player.get_node_or_null("Camera3D/ViewModel") as Node3D
	var left_arm := player.get_node_or_null("Camera3D/ViewModel/LeftArmFP") as MeshInstance3D
	var right_arm := player.get_node_or_null("Camera3D/ViewModel/RightArmFP") as MeshInstance3D
	var left_hand := player.get_node_or_null("Camera3D/ViewModel/LeftHandFP") as MeshInstance3D
	var right_hand := player.get_node_or_null("Camera3D/ViewModel/RightHandFP") as MeshInstance3D
	var holder := player.get_node_or_null("Camera3D/ViewModel/ToolHolder") as Node3D
	var tool := player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool") as Node3D

	_check(camera != null, "first-person camera missing")
	_check(camera != null and camera.current, "first-person camera must be current")
	_check(viewmodel != null, "viewmodel missing")
	_check(left_arm != null and right_arm != null, "first-person arms missing")
	_check(left_hand != null and right_hand != null, "first-person hands missing")
	_check(holder != null and tool != null, "tool holder hierarchy missing")
	_check(left_arm != null and left_arm.layers == 2, "left arm must use viewmodel render layer")
	_check(right_arm != null and right_arm.layers == 2, "right arm must use viewmodel render layer")
	_check(left_hand != null and left_hand.layers == 2, "left hand must use viewmodel render layer")
	_check(right_hand != null and right_hand.layers == 2, "right hand must use viewmodel render layer")
	_check(camera != null and (camera.cull_mask & 2) != 0, "camera must render viewmodel layer")
	_check(right_hand != null and right_hand.position.z < -0.5, "right hand must be in front of camera")
	_check(holder != null and holder.position.z < -0.5, "tool holder must be in front of camera")
	player.queue_free()

func _test_first_person_presentation_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var tool_holder := player.get_node_or_null("Camera3D/ViewModel/ToolHolder") as Node3D
	var chest := player.get_node_or_null("Camera3D/ViewModel/ChestFP") as MeshInstance3D
	var left_leg := player.get_node_or_null("Camera3D/ViewModel/LeftLegFP") as MeshInstance3D
	var right_leg := player.get_node_or_null("Camera3D/ViewModel/RightLegFP") as MeshInstance3D
	var hotbar := player.get_node_or_null("HUDInventory/ToolHotbar") as Control
	_check(tool_holder != null, "tool holder must exist for first-person presentation")
	_check(chest != null and left_leg != null and right_leg != null, "first-person body viewmodel must include torso and legs")
	_check(chest != null and chest.layers == 2, "first-person chest must use viewmodel layer")
	_check(hotbar != null and is_equal_approx(hotbar.anchor_left, 0.5) and is_equal_approx(hotbar.anchor_right, 0.5), "tool hotbar must be centered")
	_check(player.has_method("play_tool_use"), "player must expose tool use presentation")
	player.queue_free()

func _test_resource_interaction_matrix() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.add_item("I01_STONE_AXE", 1)
	inventory.add_item("I02_STONE_PICK", 1)

	var resource_scene := load("res://scenes/resource_node.tscn") as PackedScene
	var tree := resource_scene.instantiate()
	root.add_child(tree)
	tree.resource_type = "Wood"
	tree.tool_required = "I01_STONE_AXE"
	tree.amount = 3
	tree.remaining = 3

	var stone := resource_scene.instantiate()
	root.add_child(stone)
	stone.resource_type = "Stone"
	stone.tool_required = "I02_STONE_PICK"
	stone.amount = 3
	stone.remaining = 3

	var lux := resource_scene.instantiate()
	root.add_child(lux)
	lux.resource_type = "Vitreous Lux"
	lux.tool_required = "I02_STONE_PICK"
	lux.amount = 1
	lux.remaining = 1

	_check(player.set_tool(VeyraItemCatalog.HANDS_ID), "hands selection should succeed")
	_check(not tree.can_interact(player), "tree must reject hands")
	_check(not stone.can_interact(player), "stone must reject hands when pick is required")

	_check(player.set_tool("I01_STONE_AXE"), "axe selection should succeed")
	_check(tree.can_interact(player), "tree must accept stone axe")
	_check(not stone.can_interact(player), "stone must reject stone axe")

	_check(player.set_tool("I02_STONE_PICK"), "pick selection should succeed")
	_check(not tree.can_interact(player), "tree must reject stone pick")
	_check(stone.can_interact(player), "stone must accept stone pick")
	_check(lux.can_interact(player), "Vitreous Lux must accept stone pick")

	tree.queue_free()
	stone.queue_free()
	lux.queue_free()
	player.queue_free()

func _test_resource_collision_contract() -> void:
	var resource_scene := load("res://scenes/resource_node.tscn") as PackedScene
	var resource := resource_scene.instantiate()
	root.add_child(resource)
	resource.resource_id = "TEST-001"
	resource.resource_type = "Stone"
	resource.amount = 3
	_check(resource.collision_layer == 4, "resource must remain a collidable interactable on layer 4")
	_check(resource.collision_mask == 1, "resource should detect terrain layer 1")
	var test_player_scene := load("res://scenes/player.tscn") as PackedScene
	var test_player := test_player_scene.instantiate()
	root.add_child(test_player)
	_check(resource.can_interact(test_player), "resource should be interactable with hands")
	test_player.queue_free()
	resource._deplete()
	_check(resource.collision_layer == 0, "depleted resource must disable collision")
	resource._restore()
	_check(resource.collision_layer == 4, "restored resource must regain interaction collision")
	resource.queue_free()


func _test_npc_simulation_layer() -> void:
	var definition := NPCDefinition.new("human_worker", "Worker", "human", 3.5, 1.0, 20, ["BUILD"], "worker_01")
	var state := NPCState.new("npc_sim_01", "human_worker")

	_check(definition.is_valid(), "simulation definition must be valid")
	_check(state.is_valid(), "simulation state must be valid")

	var initial_hunger: float = state.hunger
	_check(NPCSimulation.process_tick(state, definition, 0.0), "zero delta tick should succeed")
	_check(state.hunger == initial_hunger, "zero delta must produce no state mutations")

	_check(not NPCSimulation.process_tick(state, definition, -1.0), "negative delta must be rejected")
	_check(state.hunger == initial_hunger, "rejected negative delta must leave state unmodified")

	_check(NPCSimulation.process_tick(state, definition, 10.0), "valid tick processing should succeed")
	_check(state.hunger < initial_hunger, "hunger must deterministically decay after positive delta")

	var state_a := NPCState.new("npc_a", "human_worker")
	var state_b := NPCState.new("npc_b", "human_worker")
	NPCSimulation.process_tick(state_a, definition, 25.0)
	NPCSimulation.process_tick(state_b, definition, 25.0)
	_check(state_a.hunger == state_b.hunger, "identical inputs must yield identical hunger outputs")
	_check(state_a.thirst == state_b.thirst, "identical inputs must yield identical thirst outputs")
	_check(state_a.health == state_b.health, "identical inputs must yield identical health outputs")

	state.alive = false
	var dead_hunger: float = state.hunger
	_check(NPCSimulation.process_tick(state, definition, 10.0), "dead NPC processing should be accepted without updates")
	_check(state.hunger == dead_hunger, "dead NPC must undergo no needs updates")

func _test_npc_simulation_definition_separation() -> void:
	var definition := NPCDefinition.new("human_worker", "Worker")
	var state := NPCState.new("npc_sep_01", "human_worker")
	var before := definition.to_dict()
	_check(NPCSimulation.process_tick(state, definition, 5.0), "definition separation tick should succeed")
	_check(definition.to_dict() == before, "NPCDefinition must remain unmodified by simulation ticks")



func _test_full_game_skeleton_contracts() -> void:
	var job_def := JobDefinition.new("job_gather", "Gather Wood", "GATHER", 1, ["worker"], [], ["axe"], 5.0)
	_check(job_def.is_valid(), "job definition must be valid")
	var job_manager := JobManager.new()
	_check(job_manager.register_definition(job_def), "job definition registration must succeed")
	var job_state := job_manager.create_job("job_01", "job_gather")
	_check(job_state != null and job_state.is_valid(), "job state must be created")
	_check(job_manager.assign_worker("job_01", "npc_worker_1"), "job assignment must succeed")

	var animal_def := AnimalDefinition.new("deer", "Forest Deer", "cervid")
	var animal_state := AnimalState.new("animal_01", "deer")
	_check(animal_def.is_valid() and animal_state.is_valid(), "animal contracts must be valid")
	var animal_hunger := animal_state.hunger
	_check(AnimalSimulation.process_tick(animal_state, animal_def, 10.0), "animal simulation tick must succeed")
	_check(animal_state.hunger < animal_hunger, "animal hunger must decay")

	var enemy_def := EnemyDefinition.new("wolf", "Shadow Wolf")
	var enemy_state := EnemyState.new("enemy_01", "wolf")
	_check(enemy_def.is_valid() and enemy_state.is_valid(), "enemy contracts must be valid")
	_check(EnemySimulation.process_tick(enemy_state, enemy_def, 1.0), "enemy simulation tick must succeed")

	var production_def := ProductionDefinition.new("plank_prod", {"Wood": 2}, {"Plank": 1}, 10.0, "sawmill", "worker")
	var production_manager := ProductionManager.new()
	_check(production_manager.register_definition(production_def), "production registration must succeed")
	var production_state := production_manager.create_production("prod_01", "plank_prod", "bld_01")
	_check(production_state != null, "production state must be created")
	production_state.active = true
	_check(production_manager.advance_progress("prod_01", 10.0), "production should complete at duration")

	var additive := ModifierDefinition.new("add", "speed", ModifierDefinition.ModifierType.ADDITIVE, 2.0)
	var multiplier := ModifierDefinition.new("mult", "speed", ModifierDefinition.ModifierType.MULTIPLICATIVE, 1.5)
	_check(is_equal_approx(ModifierSystem.calculate_modified_value(10.0, [additive, multiplier]), 18.0), "modifier calculation mismatch")

	var quest_def := QuestDefinition.new("quest_01", "First Task")
	var quest_state := QuestState.new("quest_state_01", "quest_01")
	_check(quest_def.is_valid() and quest_state.is_valid(), "quest contracts must be valid")

	var event_def := EventDefinition.new("event_01", "Lunar Disturbance", 60.0)
	var event_manager := EventManager.new()
	_check(event_manager.register_definition(event_def), "event registration must succeed")
	var event_state := event_manager.trigger_event("event_state_01", "event_01")
	_check(event_state != null and event_state.active, "event should trigger")

	var raw_job := JobState.from_dict({"job_id": "raw", "definition_id": "job_gather", "progress": -10.0})
	_check(raw_job.progress == -10.0 and not raw_job.is_valid(), "job deserialization must preserve invalid raw state")

func _test_npc_definition_data_layer() -> void:
	var definition := NPCDefinition.new("human_gatherer", "Gatherer", "human", 4.0, 1.2, 25, ["GATHER", "HAUL"], "villager_01")
	_check(definition.is_valid(), "valid NPC definition must pass validation")
	var invalid_definition := NPCDefinition.new("", "", "human", -1.0, -0.5, -10)
	_check(not invalid_definition.is_valid(), "invalid NPC definition must fail validation")
	var restored := NPCDefinition.from_dict(definition.to_dict())
	_check(restored.id == definition.id, "NPC definition ID round trip mismatch")
	_check(restored.base_movement_speed == definition.base_movement_speed, "NPC definition speed round trip mismatch")
	_check(restored.preferred_jobs == definition.preferred_jobs, "NPC definition jobs round trip mismatch")

func _test_npc_state_data_layer() -> void:
	var state := NPCState.new("npc_001", "human_gatherer")
	state.position = NPCState.make_vector_dict(10.0, 0.0, -5.0)
	_check(state.is_valid(), "valid initial NPC state must pass validation")
	var invalid_state := NPCState.new("", "")
	_check(not invalid_state.is_valid(), "NPC state with empty IDs must fail validation")
	state.update_needs(10.0)
	_check(state.hunger < 100.0, "NPC hunger should decay deterministically")
	_check(state.thirst < 100.0, "NPC thirst should decay deterministically")
	var restored := NPCState.from_dict(state.to_dict())
	_check(restored.npc_id == "npc_001", "NPC state ID round trip mismatch")
	_check(restored.position["x"] == 10.0, "NPC state X position round trip mismatch")
	_check(restored.position["z"] == -5.0, "NPC state Z position round trip mismatch")
	_check(restored.is_valid(), "restored NPC state must pass validation")

func _test_npc_state_validation_vs_sanitization() -> void:
	var corrupted := NPCState.from_dict({
		"npc_id": "corrupted_01",
		"definition_id": "human_worker",
		"health": -50.0
	})
	_check(corrupted.health == -50.0, "from_dict must preserve invalid health without clamping")
	_check(not corrupted.is_valid(), "corrupted NPC state must fail validation")
	corrupted.sanitize()
	_check(corrupted.health == 0.0, "sanitize must clamp negative health")
	_check(not corrupted.alive, "sanitize must mark zero-health NPC dead")
