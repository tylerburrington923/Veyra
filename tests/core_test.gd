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
	if failures.is_empty():
		print("VEYRA CORE TESTS: PASS (5 suites)")
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
	var tool_button := player.get_node_or_null("HUDInventory/ToolButton") as Button
	_check(tool_button != null, "mobile tool selector missing")
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
	resource._deplete()
	_check(resource.collision_layer == 0, "depleted resource must disable collision")
	resource._restore()
	_check(resource.collision_layer == 4, "restored resource must regain interaction collision")
	resource.queue_free()
