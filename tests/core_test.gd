extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_inventory_round_trip()
	_test_inventory_capacity_contract()
	_test_crafting_transaction()
	_test_collision_contract()
	_test_tool_state_contract()
	_test_resource_collision_contract()
	_test_tool_catalog_contract()
	_test_first_person_viewmodel_contract()
	_test_first_person_presentation_contract()
	_test_resource_interaction_matrix()
	_test_world_resource_tool_contract()
	_test_hand_gathered_wood_contract()
	_test_npc_definition_data_layer()
	_test_npc_state_data_layer()
	_test_npc_state_validation_vs_sanitization()
	_test_npc_simulation_layer()
	_test_npc_simulation_definition_separation()
	_test_npc_controller_presentation_contract()
	_test_npc_manager_contract()
	_test_npc_beta_wander_contract()
	_test_npc_trade_and_service_contract()
	_test_wildlife_beta_contract()
	_test_wildlife_generation_contract()
	_test_wildlife_combat_contract()
	_test_wildlife_meat_hide_contract()
	_test_wildlife_empty_snapshot_contract()
	_test_full_game_skeleton_contracts()
	_test_tree_harvest_visual_contract()
	_test_house_door_contract()
	_test_house_geometry_contract()
	_test_townhall_contract()
	_test_townhall_civic_contract()
	_test_building_placement_contract()
	_test_empty_new_inventory_contract()
	_test_mobile_action_layout_contract()
	_test_water_system_contract()
	_test_mobile_backpack_contract()
	_test_building_interaction_contract()
	_test_building_storage_contract()
	_test_storage_protects_tools_contract()
	_test_campfire_and_townhall_contract()
	_test_settlement_water_contract()
	_test_multiplayer_contract()
	_test_multiplayer_ui_contract()
	_test_pause_menu_contract()
	_test_active_npc_contract()
	_test_npc_work_contract()
	_test_blacksmith_contract()
	_test_advanced_tool_and_hide_contract()
	_test_building_catalog_contract()
	_test_simulation_cadence_contract()
	_test_job_simulation_contract()
	_test_settlement_production_loop()
	_test_settlement_production_save_contract()
	_test_performance_cache_contract()
	_test_alpha_presentation_contract()
	if failures.is_empty():
		print("VEYRA CORE TESTS: PASS (53 suites)")
		quit(0)
	else:
		for failure in failures:
			push_error("VEYRA CORE TEST FAILURE: " + failure)
		quit(1)


func _test_tree_harvest_visual_contract() -> void:
	var foliage_script := load("res://scripts/foliage_patch.gd")
	var foliage: Node3D = foliage_script.new()
	root.add_child(foliage)

	var mesh := BoxMesh.new()
	var trunk := MultiMeshInstance3D.new()
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = mesh
	trunk_mm.instance_count = 1
	trunk_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	trunk.multimesh = trunk_mm
	root.add_child(trunk)

	var canopy := MultiMeshInstance3D.new()
	var canopy_mm := MultiMesh.new()
	canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_mm.mesh = mesh
	canopy_mm.instance_count = 1
	canopy_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)))
	canopy.multimesh = canopy_mm
	root.add_child(canopy)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collision.shape = shape
	root.add_child(collision)

	foliage._set_tree_visual(
		trunk,
		canopy,
		0,
		Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)),
		false
	)
	var depleted_state: Dictionary = foliage.get_tree_visual_state(0)
	_check(not bool(depleted_state.get("active", true)), "depleted tree visual state must be inactive")
	_check(float((depleted_state.get("trunk_transform", Transform3D())).origin.y) < -9999.0, "depleted tree trunk visual state must hide")
	_check(float((depleted_state.get("leaf_transform", Transform3D())).origin.y) < -9999.0, "depleted tree canopy visual state must hide")

	foliage._set_tree_visual(
		trunk,
		canopy,
		0,
		Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)),
		true
	)
	var restored_state: Dictionary = foliage.get_tree_visual_state(0)
	_check(bool(restored_state.get("active", false)), "respawned tree visual state must be active")
	_check(absf(float((restored_state.get("trunk_transform", Transform3D())).origin.y) - 1.0) < 0.001, "respawned tree trunk visual state must restore")
	_check(absf(float((restored_state.get("leaf_transform", Transform3D())).origin.y) - 2.0) < 0.001, "respawned tree canopy visual state must restore")

	foliage.queue_free()
	trunk.queue_free()
	canopy.queue_free()
	collision.queue_free()


func _test_house_door_contract() -> void:
	_check(VeyraBuildingCatalog.get_building("B03_SHELTER").get("name", "") == "House", "shelter display name must be House")
	var house := VeyraBuildingInstance.new()
	root.add_child(house)
	house.setup("TEST-HOUSE", "B03_SHELTER", Vector3.ZERO)
	_check(house.can_interact(null), "house door must be interactable")
	_check(not house.door_open, "house door must start closed")
	var door_collision: CollisionShape3D = house._door_collision
	_check(door_collision != null and not door_collision.disabled, "closed house door must block the doorway")
	house.interact()
	_check(house.door_open, "house door must open on interaction")
	_check(door_collision != null and door_collision.disabled, "open house door must clear its collision")
	house.interact()
	_check(not house.door_open, "house door must close on second interaction")
	_check(door_collision != null and not door_collision.disabled, "closed house door must restore collision")
	house.queue_free()


func _test_house_geometry_contract() -> void:
	var house := VeyraBuildingInstance.new()
	root.add_child(house)
	house.setup("TEST-HOUSE-GEOMETRY", "B03_SHELTER", Vector3.ZERO)

	var left_roof := house.get_node_or_null("RoofLeft") as MeshInstance3D
	var right_roof := house.get_node_or_null("RoofRight") as MeshInstance3D
	var back_wall := house.get_node_or_null("BackWallCollision") as CollisionShape3D
	_check(left_roof != null and right_roof != null, "house roof panels must exist")
	_check(left_roof != null and absf(left_roof.rotation.x) < 0.001, "left roof must slope around Z, not X")
	_check(right_roof != null and absf(right_roof.rotation.x) < 0.001, "right roof must slope around Z, not X")
	_check(left_roof != null and left_roof.rotation.z > 0.3, "left roof must slope up toward the ridge")
	_check(right_roof != null and right_roof.rotation.z < -0.3, "right roof must slope up toward the ridge")
	_check(back_wall != null, "house must have an explicit back wall collision")
	if back_wall:
		_check(not back_wall.disabled, "house back wall collision must be enabled")
		_check(back_wall.position.z > 2.0, "house back wall collision must sit on the rear wall")
	house.queue_free()


func _test_townhall_contract() -> void:
	var definition := VeyraBuildingCatalog.get_building("B05_TOWNHALL")
	_check(not definition.is_empty(), "town hall catalog entry must exist")
	_check(str(definition.get("name", "")) == "Town Hall", "town hall display name must be Town Hall")
	_check(definition.get("size", Vector2.ZERO) == Vector2(8.0, 7.0), "town hall footprint must be 8x7")
	_check(int(definition.get("cost", {}).get("Wood", 0)) == 60, "town hall wood cost must be 60")
	_check(int(definition.get("cost", {}).get("Stone", 0)) == 40, "town hall stone cost must be 40")

	var hall := VeyraBuildingInstance.new()
	root.add_child(hall)
	hall.setup("TEST-TOWNHALL", "B05_TOWNHALL", Vector3.ZERO)
	var collision_count := 0
	for child in hall.get_children():
		if child is CollisionShape3D:
			collision_count += 1
	_check(collision_count >= 2, "town hall must have solid collision")
	_check(hall.get_child_count() >= 20, "town hall must have a substantial civic visual assembly")
	_check(hall.get_node_or_null("RoofLeft") != null and hall.get_node_or_null("RoofRight") != null, "town hall must have a pitched main roof")
	_check(hall.get_node_or_null("Clock") != null and hall.get_node_or_null("ClockFace") != null, "town hall must have a readable civic clock")
	hall.queue_free()


func _test_townhall_civic_contract() -> void:
	var settlement := root.get_node_or_null("SettlementManager")
	if not settlement:
		return
	var hall := VeyraBuildingInstance.new()
	root.add_child(hall)
	hall.setup("TEST-CIVIC-HALL", "B05_TOWNHALL", Vector3.ZERO)
	settlement.add_building("TEST-CIVIC-HALL", "B05_TOWNHALL", Vector3.ZERO)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.add_resource("Wood", 10)
	inventory.add_resource("Stone", 10)
	_check(hall.deposit_civic_materials(player, 10), "town hall must accept civic material deposits")
	var state: Dictionary = settlement.get_settlement_state()
	var stock: Dictionary = state.get("stock", {})
	_check(int(stock.get("wood", 0)) >= 10, "town hall must add deposited wood to settlement stock")
	_check(int(stock.get("stone", 0)) >= 10, "town hall must add deposited stone to settlement stock")
	_check(inventory.get_amount("Wood") == 0 and inventory.get_amount("Stone") == 0, "town hall deposit must remove only the deposited material from player inventory")
	var manager := root.get_node_or_null("BuildingManager")
	if manager:
		_check(manager.has_method("_has_townhall"), "building manager must expose a Town Hall uniqueness guard")
		_check(bool(manager.call("_has_townhall")), "building manager must detect an existing Town Hall")
	player.queue_free()
	hall.queue_free()

func _test_building_placement_contract() -> void:
	var manager := VeyraBuildingManager.new()
	root.add_child(manager)
	_check(manager.MAX_BUILD_DISTANCE > manager.MIN_BUILD_DISTANCE, "building placement range must be coherent")
	_check(manager.GRID_SIZE > 0.0, "building placement grid must be positive")
	_check(manager.has_method("server_build"), "building manager must expose request-local authoritative build validation")
	_check(manager.snap_position(Vector3(1.49, 3.2, -2.51)) == Vector3(1.0, 3.2, -3.0), "building placement must snap only X/Z while preserving terrain Y")
	manager.queue_free()

func _test_empty_new_inventory_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	_check(inventory.get_amount("Wood") == 0, "new player must not receive starter wood")
	_check(inventory.get_amount("Stone") == 0, "new player must not receive starter stone")
	player.queue_free()


func _test_mobile_action_layout_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var jump_button := player.get_node_or_null("MobileControls/JumpButton") as Button
	var use_button := player.get_node_or_null("MobileControls/InteractButton") as Button
	var craft_ui := player.get_node_or_null("CraftBuildUI") as VeyraCraftBuildUI
	var craft_button: Button = craft_ui.crafting_button if craft_ui else null
	_check(jump_button != null and use_button != null and craft_button != null, "mobile action controls must exist")
	if jump_button and use_button and craft_button:
		_check(not craft_button.get_global_rect().intersects(jump_button.get_global_rect()), "crafting button must not overlap jump button")
		_check(not craft_button.get_global_rect().intersects(use_button.get_global_rect()), "crafting button must not overlap use button")
	player.queue_free()

func _test_interaction_hud_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var panel := player.get_node_or_null("MobileControls/InteractionHUD") as PanelContainer
	var action := player.get_node_or_null("MobileControls/InteractionHUD/Action") as Label
	var detail := player.get_node_or_null("MobileControls/InteractionHUD/Detail") as Label
	_check(panel != null and action != null and detail != null, "interaction HUD hierarchy must exist")
	if panel:
		_check(panel.size.x <= 240.0 and panel.size.y <= 52.0, "interaction HUD must remain compact")
	player.queue_free()

func _test_multiplayer_ui_contract() -> void:
	var network_script := load("res://scripts/network_manager.gd")
	var manager = network_script.new()
	root.add_child(manager)
	_check(manager.has_method("close_lobby_ui"), "multiplayer manager must expose a deterministic lobby close action")
	manager._build_lobby_ui()
	var lobby = manager.get("lobby_layer")
	_check(lobby != null, "multiplayer lobby layer must be created")
	if lobby:
		var panel := lobby.get_node_or_null("MultiplayerPanel") as Control
		_check(panel != null, "multiplayer lobby panel must exist")
		if panel:
			_check(panel.get_node_or_null("CLOSE") != null, "multiplayer lobby must expose a close button")
	manager.queue_free()

func _test_pause_menu_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var pause_script = load("res://scripts/pause_menu.gd")
	var menu := pause_script.new() as CanvasLayer
	root.add_child(menu)
	_check(menu != null, "pause menu must instantiate")
	var menu_button := menu.get_node_or_null("MenuButton") as Button if menu else null
	_check(menu_button != null, "pause menu must expose top-corner menu button")
	_check(menu != null and menu.visible, "pause canvas layer must remain visible while the world is active")
	if menu_button:
		var viewport_size := menu.get_viewport().get_visible_rect().size
		_check(menu_button.position.x >= 0.0 and menu_button.position.x + menu_button.size.x <= viewport_size.x, "pause button must remain inside viewport")
		_check(menu_button.position.y >= 0.0 and menu_button.position.y + menu_button.size.y <= viewport_size.y, "pause button must remain inside viewport vertically")
		menu_button.emit_signal("pressed")
		_check(menu.visible and menu.get_node_or_null("PausePanel").visible, "pause button must open the in-game menu panel")
		var multiplayer_button := menu.get_node_or_null("PausePanel/MULTIPLAYER") as Button
		_check(multiplayer_button != null, "pause menu must expose multiplayer button")
		var panel := menu.get_node_or_null("PausePanel") as Control
		_check(panel != null and panel.position.x >= 0.0 and panel.position.y >= 0.0, "pause panel must be positioned inside viewport")
		menu_button.emit_signal("pressed")
		_check(menu.visible and not menu.get_node_or_null("PausePanel").visible, "pause button must close only the in-game menu panel")
	menu.queue_free()
	var main_menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	_check(main_menu_scene != null, "main menu scene must load")
	_check(menu_button != null and menu_button.is_in_group("camera_blocking_ui"), "menu button must block camera touch")
	player.queue_free()


func _test_active_npc_contract() -> void:
	var manager := NPCManager.new()
	root.add_child(manager)
	var npc: NPCController = manager.spawn_npc("test_active_npc", "human_villager", Vector3.ZERO)
	_check(npc != null, "NPC manager must spawn an active villager controller")
	_check(manager.get_npc_state("test_active_npc") != null, "active NPC state must exist")
	if npc:
		_check(npc.get_node_or_null("Visual") != null, "active NPC must have a visual")
		var visual := npc.get_node_or_null("Visual") as NPCVisual
		if visual:
			_check(visual.get_node_or_null("Neck") != null, "villager visual must have a readable neck")
			_check(visual.get_node_or_null("Buckle") != null, "villager visual must have readable clothing detail")
			_check(visual.get_node_or_null("LeftEye") != null and visual.get_node_or_null("RightEye") != null, "villager visual must have readable eyes")
			_check(visual.get_node_or_null("LeftArmPivot") != null and visual.get_node_or_null("RightArmPivot") != null, "villager arms must animate from shoulder pivots")
			_check(visual.get_node_or_null("LeftLegPivot") != null and visual.get_node_or_null("RightLegPivot") != null, "villager legs must animate from hip pivots")
	manager.despawn_npc("test_active_npc")
	manager.queue_free()


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
	var holder := player.get_node_or_null("Camera3D/ViewModel/ToolHolder") as Node3D
	var tool := player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool") as Node3D
	var body_left_arm := player.get_node_or_null("LeftArm") as MeshInstance3D
	var body_right_arm := player.get_node_or_null("RightArm") as MeshInstance3D
	var body_left_hand := player.get_node_or_null("LeftHand") as MeshInstance3D
	var body_right_hand := player.get_node_or_null("RightHand") as MeshInstance3D

	_check(camera != null, "first-person camera missing")
	_check(camera != null and camera.current, "first-person camera must be current")
	_check(viewmodel != null, "viewmodel root missing")
	_check(holder != null and tool != null, "tool holder hierarchy missing")
	_check(body_left_arm != null and body_right_arm != null, "coherent world-body arms missing")
	_check(body_left_hand != null and body_right_hand != null, "coherent world-body hands missing")
	_check(camera != null and (camera.cull_mask & 1) != 0 and (camera.cull_mask & 2) != 0, "camera must render world and viewmodel layers")
	_check(player.get_node_or_null("Camera3D/ViewModel/LeftArmFP") != null, "first-person left arm presentation must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/RightArmFP") != null, "first-person right arm presentation must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/LeftHandFP") != null, "first-person left hand presentation must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/RightHandFP") != null, "first-person right hand presentation must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/LeftCuffFP") != null, "first-person left sleeve cuff must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/RightCuffFP") != null, "first-person right sleeve cuff must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/ToolGrip") != null, "tool grip visual must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeCollar") != null, "axe collar visual must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeLashUpper") != null, "axe upper binding visual must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/AxeLashLower") != null, "axe lower binding visual must exist")
	_check(player.get_node_or_null("Camera3D/ViewModel/ToolHolder/EquippedTool/PickCollar") != null, "pick collar visual must exist")
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
	var left_sleeve := player.get_node_or_null("Camera3D/ViewModel/LeftSleeveFP") as MeshInstance3D
	var right_sleeve := player.get_node_or_null("Camera3D/ViewModel/RightSleeveFP") as MeshInstance3D
	_check(left_sleeve != null and right_sleeve != null, "first-person body viewmodel must include sleeves")
	_check(left_sleeve != null and (left_sleeve.layers & 2) != 0, "left first-person sleeve must render on the camera view layer")
	_check(right_sleeve != null and (right_sleeve.layers & 2) != 0, "right first-person sleeve must render on the camera view layer")
	_check(chest != null and (chest.layers & 2) != 0, "first-person body torso must render on the camera view layer")
	_check(hotbar != null and is_equal_approx(hotbar.anchor_left, 0.5) and is_equal_approx(hotbar.anchor_right, 0.5), "tool hotbar must be centered")
	_check(player.has_method("play_tool_use"), "player must expose tool use presentation")
	var fp_left_arm := player.get_node_or_null("Camera3D/ViewModel/LeftArmFP") as MeshInstance3D
	var fp_right_arm := player.get_node_or_null("Camera3D/ViewModel/RightArmFP") as MeshInstance3D
	var world_left_arm := player.get_node_or_null("LeftArm") as MeshInstance3D
	_check(fp_left_arm != null and fp_left_arm.visible, "local first-person arm must be visible")
	_check(fp_right_arm != null and fp_right_arm.visible, "local first-person arm must be visible")
	_check(world_left_arm != null and not world_left_arm.visible, "local world arm must be hidden to prevent camera-body distortion")
	var world_torso := player.get_node_or_null("Torso") as MeshInstance3D
	_check(world_torso != null and not world_torso.visible, "local torso must be hidden from first-person camera")
	_check(player.set_tool(VeyraItemCatalog.HANDS_ID), "hands must be selectable for punch presentation")
	player.play_tool_use()
	_check(bool(player.get("_punch_active")), "hands use must trigger punch animation")
	player._update_tool_animation(0.10)
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

func _test_world_resource_tool_contract() -> void:
	var world_generator = load("res://scripts/world_generator.gd").new()

	_check(world_generator.get_required_tool_for_resource("Wood") == VeyraItemCatalog.HANDS_ID, "world-generated ground wood must require hands")
	_check(world_generator.get_required_tool_for_resource("Stone") == VeyraItemCatalog.HANDS_ID, "world-generated field stone must require hands")
	_check(world_generator.get_required_tool_for_resource("Metal") == "I02_STONE_PICK", "world-generated metal must require the stone pick")
	_check(world_generator.get_required_tool_for_resource("Vitreous Lux") == "I02_STONE_PICK", "world-generated lux must require the stone pick")

	world_generator.free()


func _test_hand_gathered_wood_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.add_item("I01_STONE_AXE", 1)

	var resource_scene := load("res://scenes/resource_node.tscn") as PackedScene
	var wood := resource_scene.instantiate()
	root.add_child(wood)
	wood.resource_type = "Wood"
	wood.tool_required = VeyraItemCatalog.HANDS_ID
	wood.amount = 3
	wood.remaining = 3

	_check(player.set_tool(VeyraItemCatalog.HANDS_ID), "hands selection should succeed for wood test")
	_check(wood.can_interact(player), "ground wood should be gatherable by hands")
	_check(wood.get_interaction_point().y < wood.global_position.y + 0.2, "ground wood interaction point must stay near the sticks")

	_check(player.set_tool("I01_STONE_AXE"), "axe selection should succeed for wood restriction test")
	_check(not wood.can_interact(player), "hand-gathered wood must reject the axe")

	wood.queue_free()
	player.queue_free()


func _test_tree_harvest_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.add_item("I01_STONE_AXE", 1)

	var resource_scene := load("res://scenes/resource_node.tscn") as PackedScene
	var tree := resource_scene.instantiate()
	root.add_child(tree)
	tree.resource_id = "D01-TREE-TEST"
	tree.resource_type = "Wood"
	tree.tool_required = "I01_STONE_AXE"
	tree.amount = 4
	tree.remaining = 4

	_check(player.set_tool("I01_STONE_AXE"), "tree test axe selection should succeed")
	_check(tree.can_interact(player), "tree resource must accept the stone axe")
	_check(player.set_tool(VeyraItemCatalog.HANDS_ID), "tree test hands selection should succeed")
	_check(not tree.can_interact(player), "tree resource must reject hands")

	tree.queue_free()
	player.queue_free()


func _test_npc_controller_presentation_contract() -> void:
	var definition := NPCDefinition.new("human_worker", "Worker", "human", 3.5, 1.0, 20, ["BUILD"], "worker_01")
	var state := NPCState.new("npc_controller_01", "human_worker")
	state.position = NPCState.make_vector_dict(4.0, 1.0, -3.0)
	state.rotation = NPCState.make_vector_dict(0.0, 1.2, 0.0)

	var controller_script := load("res://scripts/npc_controller.gd")
	var controller: Node3D = controller_script.new()
	root.add_child(controller)
	controller.configure(definition, state)

	_check(controller.authoritative_state == state, "NPC controller must reference authoritative state")
	_check(controller.definition == definition, "NPC controller must retain definition reference")
	_check(controller.global_position.is_equal_approx(Vector3(4.0, 1.0, -3.0)), "NPC controller must initialize from authoritative position")
	_check(controller.visual != null, "NPC controller must create a presentation visual")
	_check(controller.visual.get_node_or_null("Body") != null, "NPC visual body missing")
	_check(controller.visual.get_node_or_null("Head") != null, "NPC visual head missing")

	state.position = NPCState.make_vector_dict(12.0, 1.0, 2.0)
	controller.apply_authoritative_state(state)
	_check(controller.authoritative_state == state, "NPC controller must accept updated authoritative state")

	controller.queue_free()


func _test_npc_manager_contract() -> void:
	var manager_script := load("res://scripts/npc_manager.gd")
	var manager: Node3D = manager_script.new()
	root.add_child(manager)
	var controller = manager.spawn_npc("npc_manager_01", "human_worker", Vector3(2.0, 0.0, -2.0))
	_check(controller != null, "NPC manager must spawn a controller for a valid definition")
	_check(manager.states.has("npc_manager_01"), "NPC manager must retain authoritative NPC state")
	_check(manager.controllers.has("npc_manager_01"), "NPC manager must retain presentation controller")
	var state: NPCState = manager.get_npc_state("npc_manager_01")
	_check(state != null and state.definition_id == "human_worker", "NPC manager state must reference the requested definition")
	manager.despawn_npc("npc_manager_01")
	_check(not manager.states.has("npc_manager_01"), "NPC manager must remove despawned state")
	_check(not manager.controllers.has("npc_manager_01"), "NPC manager must remove despawned controller")
	manager.queue_free()


func _test_resource_respawn_contract() -> void:
	var resource_scene := load("res://scenes/resource_node.tscn") as PackedScene
	var resource := resource_scene.instantiate()
	root.add_child(resource)
	resource.resource_id = "RESPAWN-TEST"
	resource.resource_type = "Stone"
	resource.amount = 1
	resource.respawn_seconds = 1.0
	resource.remaining = 1
	_check(not resource.depleted, "resource should begin active")
	resource._deplete()
	_check(resource.depleted and not resource.visible, "depleted resource must hide")
	_check(resource.collision_layer == 0, "depleted resource collision must disable")
	resource._process(0.5)
	_check(resource.depleted, "resource must remain depleted before respawn timer")
	resource._process(0.6)
	_check(not resource.depleted and resource.visible, "resource must respawn after timer")
	_check(resource.remaining == 1, "respawn must restore full amount")
	_check(resource.collision_layer == 4, "respawn must restore interaction collision")
	resource.queue_free()


func _test_npc_job_execution_contract() -> void:
	var definition := JobDefinition.new("worker_job", "Gather Wood", "GATHER", 1, ["human"], [], ["axe"], 2.0)
	var state := NPCState.new("npc_job_01", "worker_job")
	var job := JobState.new("job_01", "worker")
	job.active = true
	_check(NPCJobSimulation.assign_job(state, definition, NPCState.make_vector_dict(4.0, 0.0, 0.0)), "NPC job assignment must succeed")
	_check(state.current_job == "worker", "NPC current job must be set")
	_check(state.current_task == "MOVE_TO_WORK", "NPC must begin by moving to work")

	_check(NPCJobSimulation.process_tick(state, definition, job, 1.0), "NPC movement tick must succeed")
	_check(float(state.position.get("x", 0.0)) > 0.0, "NPC must move toward job target")
	_check(state.current_task == "MOVE_TO_WORK", "NPC should still be travelling after first movement tick")

	_check(NPCJobSimulation.process_tick(state, definition, job, 2.0), "NPC arrival tick must succeed")
	_check(state.current_task == "WORK" or job.completed, "NPC should arrive and begin work")

	if not job.completed:
		_check(NPCJobSimulation.process_tick(state, definition, job, 2.0), "NPC work tick must succeed")
	_check(job.completed, "NPC job must complete at deterministic work duration")
	_check(not job.active, "completed job must become inactive")
	_check(state.current_task == "COMPLETE", "NPC task must report completion")


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


func _test_mobile_backpack_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var button := player.get_node_or_null("HUDInventory/BackpackButton") as Button
	var panel := player.get_node_or_null("HUDInventory/InventoryPanel") as Panel
	_check(button != null, "mobile backpack button must exist")
	_check(panel != null, "backpack inventory panel must exist")
	_check(button != null and "camera_blocking_ui" in button.get_groups(), "backpack button must block camera touch input")
	_check(panel != null and not panel.visible, "backpack panel must start closed")
	button.emit_signal("pressed")
	_check(panel != null and panel.visible, "backpack button must open inventory")
	button.emit_signal("pressed")
	_check(panel != null and not panel.visible, "backpack button must close inventory")
	player.queue_free()


func _test_building_interaction_contract() -> void:
	for building_type in ["B01_CAMPFIRE", "B02_STORAGE", "B03_SHELTER", "B04_WELL", "B05_TOWNHALL", "B06_SHRINE", "B07_WATCHTOWER", "B08_GARDEN"]:
		var building := VeyraBuildingInstance.new()
		root.add_child(building)
		building.setup("INTERACTION-" + building_type, building_type, Vector3.ZERO)
		_check(building.is_in_group("interactable"), "%s must register as an interactable" % building_type)
		_check(building.has_method("get_interaction_text"), "%s must expose interaction text" % building_type)
		_check(not building.get_interaction_text().is_empty(), "%s must expose a usable interaction action" % building_type)
		building.queue_free()


func _test_building_storage_contract() -> void:
	var settlement: Node = root.get_node_or_null("/root/SettlementManager")
	_check(settlement != null, "settlement manager must exist for building storage")
	if not settlement:
		return
	var building_id := "STORAGE-TEST-001"
	settlement.add_building(building_id, "B02_STORAGE", Vector3.ZERO)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.resources.clear()
	inventory.items.clear()
	inventory.total_weight = 0.0
	_check(inventory.add_resource("Wood", 7) == 7, "storage test must seed carried wood")
	var building := VeyraBuildingInstance.new()
	root.add_child(building)
	building.setup(building_id, "B02_STORAGE", Vector3.ZERO)
	building.interact(player)
	var ui := player.get_node_or_null("BuildingUI") as VeyraBuildingUI
	_check(ui != null and ui.visible, "storage interaction must open storage UI")
	if ui:
		ui._deposit_storage()
	_check(inventory.get_amount("Wood") == 0, "storage deposit must remove carried wood")
	var stored: Dictionary = settlement.get_building_storage(building_id)
	_check(int(stored.get("resources", {}).get("Wood", 0)) == 7, "storage must persist deposited wood")
	if ui:
		ui._withdraw_storage()
	_check(inventory.get_amount("Wood") == 7, "storage withdrawal must restore deposited wood")
	var emptied_storage: Dictionary = settlement.get_building_storage(building_id)
	_check(
		int(emptied_storage.get("resources", {}).get("Wood", 0)) == 0
		and emptied_storage.get("items", {}).is_empty(),
		"storage must be empty after full withdrawal"
	)
	settlement.buildings.erase(building_id)
	building.queue_free()
	player.queue_free()


func _test_storage_protects_tools_contract() -> void:
	var settlement: Node = root.get_node_or_null("/root/SettlementManager")
	if not settlement:
		return
	var building_id := "STORAGE-TOOLS-001"
	settlement.add_building(building_id, "B02_STORAGE", Vector3.ZERO)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.clear()
	_check(inventory.add_item("I01_STONE_AXE", 1) == 1, "storage tool test must seed axe")
	_check(inventory.add_item("I02_STONE_PICK", 1) == 1, "storage tool test must seed pick")
	var building := VeyraBuildingInstance.new()
	root.add_child(building)
	building.setup(building_id, "B02_STORAGE", Vector3.ZERO)
	building.interact(player)
	var ui := player.get_node_or_null("BuildingUI") as VeyraBuildingUI
	_check(ui != null and ui.visible, "tool storage interaction must open UI")
	if ui:
		ui._deposit_storage()
	_check(inventory.has_item("I01_STONE_AXE") and inventory.has_item("I02_STONE_PICK"), "tools must remain in personal inventory")
	settlement.buildings.erase(building_id)
	building.queue_free()
	player.queue_free()

func _test_wildlife_empty_snapshot_contract() -> void:
	var manager_script := load("res://scripts/animal_manager.gd")
	var manager: AnimalManager = manager_script.new()
	root.add_child(manager)
	var animal := manager.spawn_animal("snapshot_test", "lumen_grazer", Vector3.ZERO)
	_check(animal != null, "snapshot wildlife test animal must spawn")
	var before := manager.states.size()
	manager.apply_network_snapshot([])
	_check(manager.states.size() == before, "empty wildlife snapshot must not erase live client wildlife")
	manager.despawn_animal("snapshot_test")
	manager.queue_free()

func _test_water_system_contract() -> void:
	var generator_script := load("res://scripts/world_generator.gd")
	var water_script := load("res://scripts/water_system.gd")
	var generator: Node3D = generator_script.new()
	generator.seed_value = 47291
	root.add_child(generator)
	generator.generate()
	var water: Node3D = water_script.new()
	generator.add_child(water)
	water.configure(47291)
	water.terrain_generator = generator
	water.generate()
	_check(water.is_generated(), "water must generate from terrain and seed")
	_check(water.get_node_or_null("LakeSurface") != null, "lake surface missing")
	_check(water.get_node_or_null("LakeShore") != null, "lake shoreline missing")
	_check(water.get_node_or_null("StreamSurface") != null, "stream surface missing")
	_check(water.get_lake_center().distance_to(Vector3.ZERO) < 120.0, "water must remain inside terrain bounds")
	_check(water.get_lake_level() > -100.0 and water.get_lake_level() < 100.0, "water level out of bounds")
	water.queue_free()
	generator.queue_free()


func _test_inventory_capacity_contract() -> void:
	var inventory := VeyraInventory.new()
	inventory.max_slots = 2
	inventory.max_weight = 1000.0
	_check(inventory.add_resource("Stone", 5) == 5, "inventory should accept initial partial stack")
	_check(inventory.add_resource("Stone", 200) == 193, "inventory should respect actual remaining stack/slot capacity")
	_check(inventory.get_amount("Stone") == 198, "inventory amount should reflect stack capacity")
	inventory.clear()
	inventory.max_slots = 1
	inventory.max_weight = 10.0
	_check(inventory.add_resource("Meat", 20) == 10, "inventory should respect weight capacity for meat")
	_check(is_equal_approx(inventory.get_total_weight(), 10.0), "inventory weight should match accepted meat")

func _test_wildlife_meat_hide_contract() -> void:
	var manager_script := load("res://scripts/animal_manager.gd")
	var manager: AnimalManager = manager_script.new()
	root.add_child(manager)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.clear()
	var animal = manager.spawn_animal("meat_hide_test", "lumen_grazer", Vector3.ZERO)
	_check(animal != null, "meat/hide test animal must spawn")
	var result := manager.damage_animal("meat_hide_test", 999.0, player)
	_check(result.contains("died"), "animal must die for meat/hide drop test")
	_check(inventory.get_amount("Meat") == 3, "Lumen Grazer must drop meat")
	_check(inventory.get_amount("Hide") == 1, "Lumen Grazer must drop hide")
	manager.despawn_animal("meat_hide_test")
	manager.queue_free()
	player.queue_free()

func _test_npc_work_contract() -> void:
	var manager_script := load("res://scripts/npc_manager.gd")
	var manager: NPCManager = manager_script.new()
	root.add_child(manager)
	var settlement: VeyraSettlementManager = root.get_node_or_null("/root/SettlementManager") as VeyraSettlementManager
	_check(settlement != null, "settlement manager required for NPC work test")
	if not settlement:
		manager.queue_free()
		return
	var old_wood := settlement.wood_stock
	manager.spawn_npc("npc_worker_contract", "human_worker", Vector3.ZERO)
	var state: NPCState = manager.get_npc_state("npc_worker_contract")
	state.current_job = "BUILDER"
	state.current_task = "WORK"
	var work_target := manager._get_npc_work_target(state)
	state.position = NPCState.make_vector_dict(work_target.x, work_target.y, work_target.z)
	state.behavior_timer = 3.0
	manager._update_villager_behavior(state, 0.1)
	_check(settlement.wood_stock == old_wood + 1, "working NPC should contribute wood to settlement stock")
	_check(state.current_task == "IDLE", "working NPC should return to idle after completing work")
	manager.despawn_npc("npc_worker_contract")
	manager.queue_free()

func _test_npc_beta_wander_contract() -> void:
	var manager_script := load("res://scripts/npc_manager.gd")
	var manager: Node3D = manager_script.new()
	root.add_child(manager)
	var controller = manager.spawn_npc("npc_wander_01", "human_villager", Vector3.ZERO)
	_check(controller != null, "NPC beta wander must spawn")
	var state: NPCState = manager.get_npc_state("npc_wander_01")
	state.current_job = "IDLE"
	manager._update_villager_behavior(state, 20.0)
	_check(state.current_task == "WANDER", "idle villager should transition to wander")
	var start := Vector3(float(state.position.x), float(state.position.y), float(state.position.z))
	manager._update_villager_behavior(state, 1.0)
	var moved := Vector3(float(state.position.x), float(state.position.y), float(state.position.z))
	_check(not moved.is_equal_approx(start), "wandering villager should move")
	manager.queue_free()


func _test_npc_trade_and_service_contract() -> void:
	var manager_script := load("res://scripts/npc_manager.gd")
	var manager: NPCManager = manager_script.new()
	root.add_child(manager)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.resources.clear()
	inventory.items.clear()
	inventory.total_weight = 0.0
	var trader := manager.spawn_npc("npc_trader_test", "human_villager", Vector3.ZERO)
	var trader_state: NPCState = manager.get_npc_state("npc_trader_test")
	trader_state.current_job = "TRADER"
	inventory.add_resource("Stone", 5)
	var trade_result := manager.interact_with_npc("npc_trader_test", player)
	_check(inventory.get_amount("Stone") == 0 and inventory.get_amount("Metal") == 1, "NPC trader must perform a real inventory trade")
	_check(trade_result.contains("traded"), "NPC trader must report completed trade")
	var builder := manager.spawn_npc("npc_builder_test", "human_worker", Vector3.ZERO)
	var builder_state: NPCState = manager.get_npc_state("npc_builder_test")
	builder_state.current_job = "BUILDER"
	inventory.add_resource("Wood", 2)
	inventory.add_resource("Stone", 2)
	var service_result := manager.interact_with_npc("npc_builder_test", player)
	_check(inventory.has_item("I01_STONE_AXE"), "NPC builder service must craft a Stone Axe")
	_check(service_result.contains("crafted"), "NPC builder must report completed service")
	manager.queue_free()
	player.queue_free()


func _test_wildlife_beta_contract() -> void:
	var manager_script := load("res://scripts/animal_manager.gd")
	var manager: Node3D = manager_script.new()
	root.add_child(manager)
	var animal = manager.spawn_animal("grazer_test_01", "lumen_grazer", Vector3(3.0, 0.0, 3.0))
	_check(animal != null, "wildlife beta must spawn a Lumen Grazer visual")
	_check(manager.states.has("grazer_test_01"), "wildlife manager must retain Lumen Grazer state")
	var state: AnimalState = manager.states["grazer_test_01"]
	var hunger := state.hunger
	_check(AnimalSimulation.process_tick(state, manager.definitions["lumen_grazer"], 6.0), "wildlife simulation tick should succeed")
	manager._update_behavior(state, manager.definitions["lumen_grazer"], 8.0)
	_check(state.hunger < hunger, "wildlife simulation must update needs")
	_check(state.behavior_state == "WANDER", "Lumen Grazer beta should enter wander behavior")
	manager.despawn_animal("grazer_test_01")
	_check(not manager.states.has("grazer_test_01"), "wildlife despawn must remove authoritative state")
	manager.queue_free()



func _test_wildlife_generation_contract() -> void:
	var manager: AnimalManager = load("res://scripts/animal_manager.gd").new()
	root.add_child(manager)
	var female_visual := manager.spawn_animal("generation_female", "lumen_grazer", Vector3.ZERO)
	var male_visual := manager.spawn_animal("generation_male", "lumen_grazer", Vector3(2.0, 0.0, 0.0))
	_check(female_visual != null and male_visual != null, "generation test animals must spawn")
	var female: AnimalState = manager.states["generation_female"]
	var male: AnimalState = manager.states["generation_male"]
	female.sex = "F"
	male.sex = "M"
	female.age_seconds = 200.0
	male.age_seconds = 200.0
	female.life_stage = "ADULT"
	male.life_stage = "ADULT"
	female.reproduction_cooldown = 0.0
	male.reproduction_cooldown = 0.0
	manager.population_cap = 3
	manager._process_reproduction()
	var child: AnimalState = null
	for value in manager.states.values():
		var candidate: AnimalState = value as AnimalState
		if candidate and candidate.animal_id.begins_with("wild_gen_"):
			child = candidate
			break
	_check(child != null, "compatible adult wildlife must produce a bounded child")
	if child:
		_check(child.generation == 2, "offspring generation must advance")
		_check(child.parent_a_id == female.animal_id and child.parent_b_id == male.animal_id, "offspring must retain parent metadata")
		_check(child.life_stage == "JUVENILE", "offspring must start juvenile")
	var snapshot := manager.get_save_state()
	_check(snapshot.size() == 3, "wildlife save state must contain the bounded living population")
	var restored_manager: AnimalManager = load("res://scripts/animal_manager.gd").new()
	root.add_child(restored_manager)
	restored_manager.set_saved_state(snapshot)
	restored_manager._restore_saved_state()
	_check(restored_manager.states.size() == 3, "wildlife save restore must preserve living population")
	_check(restored_manager.states.has(child.animal_id), "wildlife save restore must preserve offspring identity")
	manager.queue_free()
	restored_manager.queue_free()


func _test_wildlife_combat_contract() -> void:
	var manager_script := load("res://scripts/animal_manager.gd")
	var manager: AnimalManager = manager_script.new()
	root.add_child(manager)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.resources.clear()
	inventory.items.clear()
	inventory.total_weight = 0.0
	var animal := manager.spawn_animal("combat_test_01", "lumen_grazer", Vector3.ZERO)
	_check(animal != null and animal.has_method("interact"), "wildlife must expose an interaction actor")
	var state: AnimalState = manager.states["combat_test_01"]
	var result := manager.damage_animal("combat_test_01", 999.0, player)
	_check(not state.alive and state.health == 0.0, "wildlife must die at zero health")
	_check(result.contains("died"), "wildlife death must report a death event")
	_check(inventory.get_amount("Meat") == 3 and inventory.get_amount("Hide") == 1, "wildlife death must produce meat and hide")
	_check((animal as Node3D).visible == false, "dead wildlife must become non-visible")
	manager.despawn_animal("combat_test_01")
	manager.queue_free()
	player.queue_free()


func _test_campfire_and_townhall_contract() -> void:
	var settlement: Node = root.get_node_or_null("/root/SettlementManager")
	_check(settlement != null, "settlement manager must exist for civic building tests")
	if not settlement:
		return
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory: VeyraInventory = player.get_inventory()
	inventory.resources.clear()
	inventory.items.clear()
	inventory.total_weight = 0.0
	_check(inventory.add_resource("Wood", 3) == 3, "campfire test must seed wood")
	var campfire := VeyraBuildingInstance.new()
	root.add_child(campfire)
	campfire.setup("CAMPFIRE-TEST", "B01_CAMPFIRE", Vector3.ZERO)
	_check(campfire.get_interaction_text() == "Open Campfire", "campfire must expose furnace-style interaction")
	_check(campfire.add_campfire_fuel(player, 1), "campfire should accept wood fuel")
	_check(inventory.get_amount("Wood") == 2, "campfire fuel must consume one wood")
	_check(campfire.get_campfire_heat() >= 29.0, "campfire fuel must create heat")
	_check(player.get_node_or_null("BuildingUI") == null, "campfire fuel API should not silently open UI")
	campfire.interact(player)
	_check(player.get_node_or_null("BuildingUI") != null, "campfire interaction must open building UI")
	campfire.queue_free()
	var townhall := VeyraBuildingInstance.new()
	root.add_child(townhall)
	townhall.setup("TOWNHALL-TEST", "B05_TOWNHALL", Vector3.ZERO)
	_check(townhall.get_interaction_text() == "Open Town Hall", "town hall must expose civic UI interaction")
	_check(townhall.deposit_civic_materials(player, 1), "town hall should accept civic material deposits")
	_check(settlement.wood_stock > 0, "town hall deposit must increase settlement wood stock")
	townhall.queue_free()
	player.queue_free()

func _test_blacksmith_contract() -> void:
	var instance := VeyraBuildingInstance.new()
	root.add_child(instance)
	instance.setup("BLACKSMITH-TEST", "B09_BLACKSMITH", Vector3.ZERO)
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var inventory := player.get_node_or_null("Inventory") as VeyraInventory
	inventory.clear()
	inventory.add_resource("Metal", 4)
	inventory.add_resource("Wood", 4)
	_check(instance.blacksmith_refine(player), "blacksmith should refine raw metal")
	_check(inventory.get_amount("Refined Metal") == 1, "refining must produce refined metal")
	_check(instance.blacksmith_forge(player, "I01_STONE_AXE") == false, "forge should require stone")
	inventory.add_resource("Stone", 1)
	_check(instance.blacksmith_forge(player, "I01_STONE_AXE"), "blacksmith should forge a tool")
	_check(inventory.has_item("I01_STONE_AXE"), "forged axe must enter inventory")
	player.queue_free()
	instance.queue_free()

func _test_advanced_tool_and_hide_contract() -> void:
	_check(VeyraItemCatalog.is_valid("I04_METAL_AXE"), "Metal Axe must be a valid item")
	_check(VeyraItemCatalog.is_valid("I07_ECHO_PICK"), "Echo Pick must be a valid item")
	_check(VeyraItemCatalog.gathering_bonus("I04_METAL_AXE", "Wood") == 2, "Metal Axe must improve gathering over stone tools")
	_check(VeyraItemCatalog.gathering_bonus("I07_ECHO_PICK", "Echo-Stone") == 3, "Echo Pick must provide the highest current gathering bonus")
	_check(VeyraItemCatalog.durability_cost("I07_ECHO_PICK", "Echo-Stone") < 1.0, "Echo tools must be more durable")
	_check(VeyraCraftingCatalog.exists("I06_ECHO_AXE"), "Echo Axe recipe must exist")
	_check(VeyraBuildingCatalog.exists("B10_TANNERY"), "Tannery must be catalogued")
	var tannery := VeyraBuildingCatalog.get_building("B10_TANNERY")
	_check(int(tannery.get("cost", {}).get("Hide", 0)) == 6, "Tannery must require Hide")
	var settlement := VeyraSettlementManager.new()
	root.add_child(settlement)
	settlement.add_building("TANNERY-TEST", "B10_TANNERY", Vector3.ZERO)
	var storage := settlement.get_building_storage("TANNERY-TEST")
	storage["resources"] = {"Hide": 4, "Wood": 2}
	settlement.set_building_storage("TANNERY-TEST", storage)
	_check(settlement.get_job_definition("TANNER") != null, "Tanner job must exist")
	settlement.queue_free()

func _test_building_catalog_contract() -> void:
	_check(VeyraBuildingCatalog.exists("B05_TOWNHALL"), "Town Hall must remain buildable")
	_check(VeyraBuildingCatalog.exists("B09_BLACKSMITH"), "Blacksmith must be catalogued")
	var blacksmith := VeyraBuildingCatalog.get_building("B09_BLACKSMITH")
	_check(int(blacksmith.get("cost", {}).get("Metal", 0)) == 10, "Blacksmith must require raw Metal")

func _test_alpha_presentation_contract() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	_check(camera != null and camera.fov <= 68.0 and camera.fov >= 64.0, "first-person camera FOV must stay in the alpha comfort range")
	_check(camera != null and camera.position.y >= 1.70, "first-person camera must sit above the legacy body intersection point")
	_check(player.get_node_or_null("MobileControls/InteractionReticle") != null, "center interaction reticle must exist")
	var chest_fp := player.get_node_or_null("Camera3D/ViewModel/ChestFP") as MeshInstance3D
	var belt_fp := player.get_node_or_null("Camera3D/ViewModel/BeltFP") as MeshInstance3D
	var left_sleeve_fp := player.get_node_or_null("Camera3D/ViewModel/LeftSleeveFP") as MeshInstance3D
	var right_sleeve_fp := player.get_node_or_null("Camera3D/ViewModel/RightSleeveFP") as MeshInstance3D
	_check(chest_fp != null and (chest_fp.layers & 2) != 0, "first-person chest must render on the camera view layer")
	_check(belt_fp != null and (belt_fp.layers & 2) != 0, "first-person belt must render on the camera view layer")
	_check(left_sleeve_fp != null and right_sleeve_fp != null, "first-person sleeves must exist for coherent arm presentation")
	_check(left_sleeve_fp != null and (left_sleeve_fp.layers & 2) != 0, "left first-person sleeve must render on the camera view layer")
	_check(right_sleeve_fp != null and (right_sleeve_fp.layers & 2) != 0, "right first-person sleeve must render on the camera view layer")
	var interaction_hud := player.get_node_or_null("MobileControls/InteractionHUD") as Control
	_check(interaction_hud != null and interaction_hud.visible, "center interaction HUD must be visible")
	_check(player.get_node_or_null("MobileControls/LunarHUD") != null, "lunar phase HUD must exist")
	_check(load("res://scripts/lunar_hud.gd") != null, "lunar HUD script must remain loadable")
	var world_text := FileAccess.get_file_as_string("res://scenes/world.tscn") if FileAccess.file_exists("res://scenes/world.tscn") else ""
	_check(not world_text.contains("WorldDetail"), "world scene must not instantiate duplicate floating detail resources")
	_check(not world_text.contains("VeyraArtifact"), "world scene must not instantiate placeholder artifact geometry")
	_check(world_text.count('[node name="AnimalManager" type="Node3D" parent="."]') == 1, "world scene must instantiate exactly one AnimalManager")
	_check(world_text.count('[ext_resource type="Script" path="res://scripts/animal_manager.gd" id="13_animals"]') == 1, "world scene must register AnimalManager script exactly once")
	player.queue_free()

	var manager := NPCManager.new()
	root.add_child(manager)
	var npc := manager.spawn_npc("rotation_contract", "human_villager", Vector3.ZERO)
	var state: NPCState = manager.get_npc_state("rotation_contract")
	state.current_task = "WANDER"
	state.target_position = NPCState.make_vector_dict(0.0, 0.0, -4.0)
	manager._move_state_toward(state, Vector3(0.0, 0.0, -4.0), 0.1)
	_check(absf(float(state.rotation.get("y", 99.0))) < 0.05, "NPC must face its forward travel direction")
	manager.despawn_npc("rotation_contract")
	manager.queue_free()


func _test_job_simulation_contract() -> void:
	var definition := JobDefinition.new(
		"JOB_TEST", "Test Job", "GENERAL", 1, ["human"], [], [], 2.0, "", 3.0, 2.0
	)
	_check(definition.is_valid(), "job definition with movement/work speeds must validate")
	var restored := JobDefinition.from_dict(definition.to_dict())
	_check(is_equal_approx(restored.base_movement_speed, 3.0), "job movement speed must round trip")
	_check(is_equal_approx(restored.base_work_speed, 2.0), "job work speed must round trip")
	var state := NPCState.new("job_npc", "human_villager")
	var job := JobState.new("job_state", "JOB_TEST")
	job.active = true
	_check(NPCJobSimulation.assign_job(state, definition, NPCState.make_vector_dict(0.0, 0.0, -1.0)), "job assignment must succeed")
	_check(NPCJobSimulation.process_tick(state, definition, job, 0.5), "job movement tick must succeed")
	_check(NPCJobSimulation.process_tick(state, definition, job, 0.5), "job state-transition tick must succeed")
	_check(NPCJobSimulation.process_tick(state, definition, job, 0.5), "job work tick must succeed")
	_check(job.progress > 0.0, "job tick must advance deterministic work progress")

func _test_settlement_production_loop() -> void:
	var settlement: VeyraSettlementManager = root.get_node_or_null("/root/SettlementManager") as VeyraSettlementManager
	_check(settlement != null, "settlement manager required for production loop")
	if not settlement:
		return
	var old_buildings := settlement.buildings.duplicate(true)
	var old_villagers := settlement.villagers.duplicate(true)
	var old_jobs := settlement.job_states.duplicate(true)
	var old_productions := settlement.production_manager.serialize_states()
	settlement.buildings.clear()
	settlement.villagers.clear()
	settlement.job_states.clear()
	settlement.production_manager.load_states({})
	settlement.add_building("PROD-STORAGE", "B02_STORAGE", Vector3.ZERO)
	settlement.add_building("PROD-CAMPFIRE", "B01_CAMPFIRE", Vector3(2.0, 0.0, 0.0))
	settlement.set_building_storage("PROD-STORAGE", {"resources": {"Meat": 2, "Wood": 1}, "items": {}})
	settlement.add_villager("production_villager", "Production Test")
	var job: JobState = settlement.prepare_villager_job("production_villager")
	_check(job != null and job.definition_id == "COOK", "villager should select cooking when campfire inputs exist")
	var manager := NPCManager.new()
	root.add_child(manager)
	var state_controller := manager.spawn_npc("production_villager", "human_villager", Vector3.ZERO)
	_check(state_controller != null, "production worker controller must spawn")
	var state: NPCState = manager.get_npc_state("production_villager")
	for i in range(20):
		manager._update_villager_behavior(state, 1.0)
		if job.completed:
			break
	_check(job.completed, "integrated NPC manager must complete the production job")
	_check(state.current_task == "IDLE", "completed production job must return the NPC to idle")
	var storage := settlement.get_building_storage("PROD-STORAGE")
	_check(int(storage.get("resources", {}).get("Food", 0)) == 3, "completed cooking production must return food to storage")
	_check(int(storage.get("resources", {}).get("Meat", 0)) == 0, "production inputs must be consumed from storage")
	settlement.buildings = old_buildings
	settlement.villagers = old_villagers
	settlement.job_states = old_jobs
	settlement.production_manager.load_states(old_productions)
	manager.queue_free()

func _test_settlement_production_save_contract() -> void:
	var save_manager := root.get_node_or_null("/root/SaveManager")
	_check(save_manager != null, "save manager required for production persistence")
	if not save_manager:
		return
	var settlement_state := {
		"version": 3,
		"name": "Production Save",
		"population": 1,
		"stock": {"food": 0, "water": 0, "wood": 0, "stone": 0},
		"buildings": {"S": {"id": "S", "type": "B02_STORAGE", "position": [0,0,0], "condition": 1.0, "door_open": false, "storage": {"resources": {"Food": 3}, "items": {}}}},
		"villagers": {"V": {"id": "V", "name": "Saver", "job": "COOK"}},
		"jobs": {"V": {"job_id": "JOB-0001", "definition_id": "COOK", "assigned_worker_id": "V", "target_building_id": "C", "progress": 2.0, "active": true, "completed": false}},
		"productions": {"PROD-0001": {"production_id": "PROD-0001", "definition_id": "cook_meat", "active": true, "progress": 2.0, "assigned_worker_id": "V", "source_building_id": "C"}},
		"next_job_index": 2
	}
	var sanitized: Dictionary = save_manager._sanitize_settlement(settlement_state)
	_check(int(sanitized.get("jobs", {}).size()) == 1, "settlement save must retain active job state")
	_check(int(sanitized.get("productions", {}).size()) == 1, "settlement save must retain active production state")
	_check(int(sanitized.get("buildings", {}).get("S", {}).get("storage", {}).get("resources", {}).get("Food", 0)) == 3, "settlement save must retain produced food")

func _test_performance_cache_contract() -> void:
	var world_script := load("res://scripts/world_generator.gd")
	_check(world_script != null, "world generator must remain loadable for terrain cache")
	var world = world_script.new()
	root.add_child(world)
	world.noise.seed = world.seed_value
	world.noise.frequency = 0.018
	world.detail_noise.seed = world.seed_value + 41
	world.detail_noise.frequency = 0.055
	world._height_cache.resize((world.grid_size + 1) * (world.grid_size + 1))
	for z in range(world.grid_size + 1):
		for x in range(world.grid_size + 1):
			world._height_cache[z * (world.grid_size + 1) + x] = world.get_height_at_world((x - world.grid_size * 0.5) * world.cell_size, (z - world.grid_size * 0.5) * world.cell_size)
	world._height_cache_ready = true
	var exact: float = world.get_height_at_world(3.25, -7.75)
	var fast: float = world.get_height_at_world_fast(3.25, -7.75)
	_check(absf(exact - fast) < 0.35, "terrain fast height cache must remain close to authoritative terrain")
	world.queue_free()

	var npc_script := load("res://scripts/npc_manager.gd")
	var npc_manager: NPCManager = npc_script.new()
	root.add_child(npc_manager)
	_check(npc_manager.get("_simulation_scratch") != null, "NPC manager must own reusable simulation scratch storage")
	var scratch_before = npc_manager.get("_simulation_scratch")
	npc_manager._simulation_scratch.append(NPCState.new("perf-test", "human_villager"))
	npc_manager._simulation_scratch.clear()
	_check(scratch_before == npc_manager.get("_simulation_scratch"), "NPC simulation scratch buffer must be reused")
	npc_manager.queue_free()

func _test_simulation_cadence_contract() -> void:
	var npc_manager := load("res://scripts/npc_manager.gd")
	var animal_manager := load("res://scripts/animal_manager.gd")
	_check(npc_manager != null and animal_manager != null, "simulation managers must remain loadable")
	_check(float(npc_manager.SIMULATION_INTERVAL) <= 0.12, "NPC simulation cadence must remain responsive")
	_check(float(animal_manager.SIMULATION_INTERVAL) <= 0.12, "wildlife simulation cadence must remain responsive")

func _test_settlement_water_contract() -> void:
	var settlement: Node = root.get_node_or_null("/root/SettlementManager")
	_check(settlement != null, "settlement manager must exist for water contract")
	if not settlement:
		return
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	player.add_to_group("player")
	var other_players: Array[Node] = []
	for existing in root.get_tree().get_nodes_in_group("player"):
		if existing != player:
			existing.remove_from_group("player")
			other_players.append(existing)
	settlement.water_stock = 0
	settlement.villagers.clear()
	settlement.add_villager("water_villager_01", "Water Test Villager")
	_check(settlement.get_active_player_count() >= 1, "water demand must count active players")
	_check(settlement.get_active_villager_count() == 1, "water demand must count villagers without NPC visuals")
	_check(settlement.get_water_demand() >= 2, "water demand must include player and villager")
	settlement.add_stock("Water", 10)
	var demand: int = settlement.get_water_demand()
	settlement._water_clock_initialized = true
	settlement._last_world_time = 899.0
	settlement.process_water_cycle(0.0, 900.0)
	_check(settlement.water_stock == 10 - demand, "lunar cycle water mismatch: before=10 demand=%d after=%d cycle_index=%d" % [demand, settlement.water_stock, settlement.water_cycle_index])
	for existing in other_players:
		if is_instance_valid(existing):
			existing.add_to_group("player")
	player.queue_free()
	settlement.villagers.clear()

func _test_multiplayer_contract() -> void:
	var network_script := load("res://scripts/network_manager.gd")
	_check(network_script != null, "multiplayer manager script must load")
	var manager = network_script.new()
	root.add_child(manager)
	_check(manager.PORT == 24567, "multiplayer LAN port must remain stable for alpha testing")
	_check(manager.MAX_PLAYERS >= 2, "multiplayer must support at least two peers")
	_check(manager.has_method("host_game"), "multiplayer manager must expose host_game")
	_check(manager.has_method("join_game"), "multiplayer manager must expose join_game")
	_check(manager.has_method("submit_local_input"), "multiplayer manager must expose client input submission")
	_check(manager.has_method("receive_snapshot"), "multiplayer manager must expose authoritative snapshot handling")
	_check(manager.has_method("receive_animal_snapshot"), "multiplayer manager must expose wildlife snapshot handling")
	_check(manager.has_method("submit_local_interaction"), "multiplayer manager must expose interaction requests")
	_check(manager.has_method("request_interaction"), "multiplayer manager must validate interaction requests on host")
	_check(manager._is_private_ipv4("192.168.43.1"), "192.168 hotspot address must be recognized")
	_check(manager._is_private_ipv4("10.0.0.1"), "10.x LAN address must be recognized")
	_check(manager._is_private_ipv4("172.20.10.1"), "172.16/12 hotspot address must be recognized")
	_check(not manager._is_private_ipv4("172.32.0.1"), "172.32.x.x must not be treated as private LAN")
	_check(not manager._is_private_ipv4("8.8.8.8"), "public IPv4 must not be treated as LAN")
	_check(not manager._is_private_ipv4("192.168.43"), "malformed IPv4 must be rejected")
	manager.queue_free()

	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_check(player_scene != null, "player scene must remain loadable for network spawning")
	var player := player_scene.instantiate()
	root.add_child(player)
	_check(player.has_method("configure_network_role"), "player must expose network role configuration")
	_check(player.has_method("set_network_input"), "player must accept authoritative network input")
	_check(player.has_method("apply_network_state"), "player must accept authoritative network state")
	player.queue_free()
